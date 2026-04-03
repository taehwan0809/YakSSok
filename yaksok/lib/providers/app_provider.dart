import 'dart:convert';

import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../services/backend_api.dart';

class AppProvider extends ChangeNotifier {
  static const String _baseUrlKey = 'backend_base_url';
  static const String _tokenKey = 'backend_token';
  static const String _scheduleStatusPrefix = 'schedule_status_';
  static const String _locationLatKey = 'current_lat';
  static const String _locationLngKey = 'current_lng';
  static const String _locationLabelKey = 'current_location_label';
  static const String _stationNameKey = 'current_station_name';
  static const String _guardianShareFrequencyKey = 'guardian_share_frequency';
  static const String _guardianShareLastPrefix = 'guardian_share_last_';

  static const double defaultLat = 37.5665;
  static const double defaultLng = 126.9780;
  static const String defaultStationName = '\uC885\uB85C\uAD6C';
  static const String defaultRegion = '\uC11C\uC6B8';
  static const String defaultBaseUrl = 'http://10.0.2.2:3000';

  final BackendApi _api = BackendApi();

  bool _isInitializing = true;
  bool _isBusy = false;
  bool _needsRegistration = false;
  String _baseUrl = defaultBaseUrl;
  String _authToken = '';
  String? _errorMessage;

  UserModel? _currentUser;
  List<MedicineSchedule> _schedules = const [];
  List<DoctorNote> _doctorNotes = const [];
  List<SymptomAnalysis> _symptomHistory = const [];
  List<MedicineSearchRecord> _medicineHistory = const [];
  WeatherSnapshot? _weatherSnapshot;
  DiseaseSnapshot? _diseaseSnapshot;
  List<Pharmacy> _pharmacies = const [];
  Map<int, Map<String, bool>> _scheduleDoseStatus = const {};
  Map<String, String> _guardianShareLastDates = const {};
  double? _currentLat;
  double? _currentLng;
  String _currentLocationLabel = '';
  String _currentStationName = defaultStationName;
  String _guardianShareFrequency = 'manual';

  AppProvider() {
    _restoreSession();
  }

  bool get isInitializing => _isInitializing;
  bool get isBusy => _isBusy;
  bool get isLoggedIn => _currentUser != null && !_needsRegistration;
  bool get needsRegistration => _needsRegistration;
  String get baseUrl => _baseUrl;
  String get authToken => _authToken;
  String? get errorMessage => _errorMessage;

  UserModel? get currentUser => _currentUser;
  List<MedicineSchedule> get schedules => _schedules;
  List<DoctorNote> get doctorNotes => _doctorNotes;
  List<SymptomAnalysis> get symptomHistory => _symptomHistory;
  List<MedicineSearchRecord> get medicineHistory => _medicineHistory;
  WeatherSnapshot? get weatherSnapshot => _weatherSnapshot;
  DiseaseSnapshot? get diseaseSnapshot => _diseaseSnapshot;
  List<Pharmacy> get pharmacies => _pharmacies;
  double get currentLat => _currentLat ?? defaultLat;
  double get currentLng => _currentLng ?? defaultLng;
  String get currentLocationLabel =>
      _currentLocationLabel.isNotEmpty ? _currentLocationLabel : '${defaultRegion} ${defaultStationName}';
  String get currentStationName =>
      _currentStationName.isNotEmpty ? _currentStationName : defaultStationName;
  String get guardianShareFrequency => _guardianShareFrequency;
  Map<String, bool> doseStatusFor(int scheduleId) =>
      _scheduleDoseStatus[scheduleId] ?? const {};

  Future<void> connect({
    required String baseUrl,
    required String token,
  }) async {
    await _runBusy(() async {
      _errorMessage = null;
      _needsRegistration = false;
      _baseUrl = baseUrl.trim().isEmpty ? defaultBaseUrl : baseUrl.trim();
      _authToken = token.trim();
      _api.configure(baseUrl: _baseUrl, token: _authToken);

      try {
        _currentUser = await _api.fetchMe();
        await _persistSession();
        await _loadInitialData();
      } on RegistrationRequiredException catch (error) {
        _currentUser = null;
        _needsRegistration = true;
        _errorMessage = error.message;
        await _persistSession();
      }
    });
  }

  Future<void> completeRegistration({
    required String name,
    required int age,
    required String gender,
    required String address,
    String guardianEmail = '',
    String guardianPhone = '',
  }) async {
    await _runBusy(() async {
      _errorMessage = null;
      final user = await _api.register(
        name: name,
        age: age,
        gender: gender,
        address: address,
        guardianEmail: guardianEmail,
        guardianPhone: guardianPhone,
      );
      _currentUser = user;
      _needsRegistration = false;
      _authToken = _api.token;
      await _persistSession();
      await _loadInitialData();
    });
  }

  Future<void> logout() async {
    final api = BackendApi()
      ..configure(baseUrl: _baseUrl, token: _authToken);
    final storedBaseUrl = _baseUrl;
    try {
      await api.logout();
    } catch (_) {
      // Ignore logout errors and clear the local session regardless.
    }

    _clearLocalState(keepBaseUrl: true);
    _baseUrl = storedBaseUrl;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  Future<void> refreshSchedules() async {
    if (!isLoggedIn) {
      return;
    }
    _schedules = await _safeLoad(() => _api.fetchSchedules(), fallback: _schedules);
    await _restoreScheduleDoseStatus();
    notifyListeners();
  }

  Future<void> refreshDoctorNotes() async {
    if (!isLoggedIn) {
      return;
    }
    _doctorNotes =
        await _safeLoad(() => _api.fetchDoctorNotes(), fallback: _doctorNotes);
    notifyListeners();
  }

  Future<DoctorNote> uploadDoctorNoteAudio({
    required Uint8List bytes,
    required String fileName,
    String? visitDate,
  }) async {
    return _runBusyValue(() async {
      final extension = _extractExtension(fileName);
      final presigned = await _api.getDoctorNotePresignedUrl(extension);
      await _api.uploadFileToPresignedUrl(
        uploadUrl: presigned.uploadUrl,
        contentType: presigned.contentType,
        bytes: bytes,
      );
      final note = await _api.processDoctorNote(
        s3Key: presigned.s3Key,
        visitDate: visitDate,
      );
      _doctorNotes = [note, ..._doctorNotes];
      await refreshSchedules();
      await _autoShareDoctorNoteIfNeeded(note.id);
      notifyListeners();
      return note;
    });
  }

  Future<void> refreshSymptomHistory() async {
    if (!isLoggedIn) {
      return;
    }
    _symptomHistory = await _safeLoad(
      () => _api.fetchSymptomHistory(),
      fallback: _symptomHistory,
    );
    notifyListeners();
  }

  Future<void> refreshMedicineHistory() async {
    if (!isLoggedIn) {
      return;
    }
    _medicineHistory = await _safeLoad(
      () => _api.fetchMedicineHistory(),
      fallback: _medicineHistory,
    );
    notifyListeners();
  }

  Future<void> loadWeather({
    double? lat,
    double? lng,
    String? stationName,
  }) async {
    if (!isLoggedIn) {
      return;
    }
    _weatherSnapshot = await _safeLoad(
      () => _api.fetchWeather(
        lat: lat ?? currentLat,
        lng: lng ?? currentLng,
        stationName: stationName ?? currentStationName,
      ),
      fallback: _weatherSnapshot,
    );
    notifyListeners();
  }

  Future<void> loadDiseases({String region = defaultRegion}) async {
    if (!isLoggedIn) {
      return;
    }
    _diseaseSnapshot = await _safeLoad(
      () => _api.fetchDiseases(region: region),
      fallback: _diseaseSnapshot,
    );
    notifyListeners();
  }

  Future<void> loadPharmacies({
    double? lat,
    double? lng,
    int radius = 1000,
  }) async {
    if (!isLoggedIn) {
      return;
    }
    _pharmacies = await _safeLoad(
      () => _api.fetchNearbyPharmacies(
        lat: lat ?? currentLat,
        lng: lng ?? currentLng,
        radius: radius,
      ),
      fallback: _pharmacies,
    );
    notifyListeners();
  }

  Future<MedicineSearchRecord> recommendMedicine(String input) async {
    if (!isLoggedIn) {
      throw const ApiException('로그인 후 약 추천 기능을 사용할 수 있습니다.');
    }
    final result = await _api.recommendMedicine(input);
    _medicineHistory = [result, ..._medicineHistory];
    notifyListeners();
    return result;
  }

  Future<SymptomAnalysis> analyzeSymptom(String symptom) async {
    if (!isLoggedIn) {
      throw const ApiException('로그인 후 증상 분석 기능을 사용할 수 있습니다.');
    }
    final result = await _api.analyzeSymptom(symptom);
    _symptomHistory = [result, ..._symptomHistory];
    await _autoShareSymptomIfNeeded(result.id);
    notifyListeners();
    return result;
  }

  Future<void> addSchedule({
    required String medicineName,
    required String scheduleText,
    String caution = '',
  }) async {
    if (!isLoggedIn) {
      throw const ApiException('로그인 후 복용 일정을 등록할 수 있습니다.');
    }
    final created = await _api.createSchedule(
      medicineName: medicineName,
      scheduleText: scheduleText,
      caution: caution,
    );
    _schedules = [created, ..._schedules];
    _scheduleDoseStatus = {
      ..._scheduleDoseStatus,
      created.id: _emptyDoseStatus(),
    };
    await _persistScheduleDoseStatus();
    notifyListeners();
  }

  Future<void> toggleScheduleActive(MedicineSchedule schedule) async {
    final updated = await _api.updateSchedule(
      id: schedule.id,
      isActive: !schedule.isActive,
    );
    _schedules = _schedules
        .map((item) => item.id == schedule.id ? updated : item)
        .toList();
    notifyListeners();
  }

  Future<void> removeSchedule(int id) async {
    await _api.deleteSchedule(id);
    _schedules = _schedules.where((item) => item.id != id).toList();
    final updatedMap = Map<int, Map<String, bool>>.from(_scheduleDoseStatus);
    updatedMap.remove(id);
    _scheduleDoseStatus = updatedMap;
    await _persistScheduleDoseStatus();
    notifyListeners();
  }

  Future<void> toggleDoseStatus({
    required int scheduleId,
    required String doseKey,
  }) async {
    final current =
        Map<String, bool>.from(_scheduleDoseStatus[scheduleId] ?? _emptyDoseStatus());
    current[doseKey] = !(current[doseKey] ?? false);
    final isCompleted = current[doseKey] ?? false;
    _scheduleDoseStatus = {
      ..._scheduleDoseStatus,
      scheduleId: current,
    };
    await _persistScheduleDoseStatus();
    if (isCompleted) {
      await _autoShareDoseIfNeeded(
        scheduleId: scheduleId,
        doseLabel: _doseLabelFromKey(doseKey),
        completed: true,
      );
    }
    notifyListeners();
  }

  Future<DoctorNote> loadDoctorNoteDetail(int id) {
    return _api.fetchDoctorNoteDetail(id);
  }

  Future<String> updateGuardianPhone(String guardianPhone) async {
    if (!isLoggedIn) {
      throw const ApiException('로그인 후 보호자 연락처를 등록할 수 있습니다.');
    }

    return _runBusyValue(() async {
      final message = await _api.updateGuardianPhone(guardianPhone);
      _currentUser = await _api.fetchMe();
      notifyListeners();
      return message;
    });
  }

  Future<String> notifyGuardian(int doctorNoteId) async {
    if (!isLoggedIn) {
      throw const ApiException('로그인 후 보호자 알림을 발송할 수 있습니다.');
    }

    return _runBusyValue(() => _api.notifyGuardian(doctorNoteId));
  }

  Future<String> notifyGuardianForSymptom(int symptomId) async {
    if (!isLoggedIn) {
      throw const ApiException('로그인 후 보호자 알림을 발송할 수 있습니다.');
    }

    return _runBusyValue(() => _api.notifyGuardianForSymptom(symptomId));
  }

  Future<String> notifyGuardianForDose({
    required int scheduleId,
    required String doseLabel,
    required bool completed,
  }) async {
    if (!isLoggedIn) {
      throw const ApiException('로그인 후 보호자 알림을 발송할 수 있습니다.');
    }

    return _runBusyValue(
      () => _api.notifyGuardianForDose(
        scheduleId: scheduleId,
        doseLabel: doseLabel,
        completed: completed,
      ),
    );
  }

  Future<void> updateProfile({
    required String name,
    required int age,
    required String gender,
    required String address,
    String guardianEmail = '',
    String guardianPhone = '',
  }) async {
    if (!isLoggedIn) {
      throw const ApiException('로그인 후 기본 정보를 수정할 수 있습니다.');
    }

    await _runBusy(() async {
      _currentUser = await _api.updateProfile(
        name: name,
        age: age,
        gender: gender,
        address: address,
        guardianEmail: guardianEmail,
        guardianPhone: guardianPhone,
      );
    });
  }

  Future<void> updateGuardianShareFrequency(String value) async {
    const allowed = {'manual', 'daily', 'always'};
    if (!allowed.contains(value)) {
      return;
    }
    _guardianShareFrequency = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_guardianShareFrequencyKey, value);
    notifyListeners();
  }

  Future<String> updateCurrentLocation({bool syncAddress = false}) async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const ApiException('위치 권한이 필요합니다. 휴대폰 설정에서 위치 권한을 허용해 주세요.');
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );

    _currentLat = position.latitude;
    _currentLng = position.longitude;

    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final parts = [
          place.administrativeArea,
          place.locality,
          place.subLocality,
          place.thoroughfare,
        ].where((item) => item != null && item.trim().isNotEmpty).cast<String>().toList();
        _currentLocationLabel = parts.isNotEmpty ? parts.join(' ') : '현재 위치';
        _currentStationName = (place.subLocality?.trim().isNotEmpty == true)
            ? place.subLocality!.trim()
            : (place.locality?.trim().isNotEmpty == true)
                ? place.locality!.trim()
                : defaultStationName;
      }
    } catch (_) {
      _currentLocationLabel = '현재 위치';
      _currentStationName = defaultStationName;
    }

    await _persistLocation();

    if (syncAddress && isLoggedIn && _currentUser != null) {
      await updateProfile(
        name: _currentUser!.name,
        age: _currentUser!.age,
        gender: _currentUser!.gender,
        address: _currentLocationLabel,
        guardianEmail: _currentUser!.guardianEmail,
        guardianPhone: _currentUser!.guardianPhone,
      );
    }

    await loadWeather();
    await loadPharmacies();
    notifyListeners();
    return _currentLocationLabel;
  }

  Future<String> fetchKakaoAuthUrl(String baseUrl) {
    return _api.fetchKakaoAuthUrl(baseUrl.trim().isEmpty ? defaultBaseUrl : baseUrl);
  }

  Future<void> _restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString(_baseUrlKey) ?? defaultBaseUrl;
    _authToken = prefs.getString(_tokenKey) ?? '';
    _currentLat = prefs.getDouble(_locationLatKey);
    _currentLng = prefs.getDouble(_locationLngKey);
    _currentLocationLabel = prefs.getString(_locationLabelKey) ?? '';
    _currentStationName = prefs.getString(_stationNameKey) ?? defaultStationName;
    _guardianShareFrequency =
        prefs.getString(_guardianShareFrequencyKey) ?? 'manual';
    _guardianShareLastDates = {
      for (final channel in ['doctor_note', 'symptom', 'dose'])
        channel: prefs.getString('$_guardianShareLastPrefix$channel') ?? '',
    };

    if (_authToken.isNotEmpty) {
      _api.configure(baseUrl: _baseUrl, token: _authToken);
      try {
        _currentUser = await _api.fetchMe();
        await _loadInitialData();
      } on RegistrationRequiredException catch (error) {
        _needsRegistration = true;
        _errorMessage = error.message;
      } on ApiException catch (error) {
        _errorMessage = error.message;
        _clearLocalState(keepBaseUrl: true);
      }
    }

    _isInitializing = false;
    notifyListeners();
  }

  Future<void> _loadInitialData() async {
    final lat = currentLat;
    final lng = currentLng;
    final stationName = currentStationName;
    _schedules = await _safeLoad(() => _api.fetchSchedules(), fallback: const []);
    _doctorNotes =
        await _safeLoad(() => _api.fetchDoctorNotes(), fallback: const []);
    _symptomHistory = await _safeLoad(
      () => _api.fetchSymptomHistory(),
      fallback: const [],
    );
    _medicineHistory = await _safeLoad(
      () => _api.fetchMedicineHistory(),
      fallback: const [],
    );
    _weatherSnapshot = await _safeLoad(
      () => _api.fetchWeather(
        lat: lat,
        lng: lng,
        stationName: stationName,
      ),
      fallback: null,
    );
    _diseaseSnapshot = await _safeLoad(
      () => _api.fetchDiseases(region: defaultRegion),
      fallback: null,
    );
    _pharmacies = await _safeLoad(
      () => _api.fetchNearbyPharmacies(
        lat: lat,
        lng: lng,
        radius: 1200,
      ),
      fallback: const [],
    );
    await _restoreScheduleDoseStatus();
  }

  Future<void> _persistSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, _baseUrl);
    await prefs.setString(_tokenKey, _authToken);
  }

  Future<void> _persistLocation() async {
    final prefs = await SharedPreferences.getInstance();
    if (_currentLat != null) {
      await prefs.setDouble(_locationLatKey, _currentLat!);
    }
    if (_currentLng != null) {
      await prefs.setDouble(_locationLngKey, _currentLng!);
    }
    await prefs.setString(_locationLabelKey, _currentLocationLabel);
    await prefs.setString(_stationNameKey, _currentStationName);
  }

  Future<void> _runBusy(Future<void> Function() action) async {
    _isBusy = true;
    notifyListeners();

    try {
      await action();
    } on ApiException catch (error) {
      _errorMessage = error.message;
      rethrow;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<T> _runBusyValue<T>(Future<T> Function() action) async {
    _isBusy = true;
    notifyListeners();

    try {
      return await action();
    } on ApiException catch (error) {
      _errorMessage = error.message;
      rethrow;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  void _clearLocalState({bool keepBaseUrl = false}) {
    _currentUser = null;
    _schedules = const [];
    _doctorNotes = const [];
    _symptomHistory = const [];
    _medicineHistory = const [];
    _weatherSnapshot = null;
    _diseaseSnapshot = null;
    _pharmacies = const [];
    _scheduleDoseStatus = const {};
    _guardianShareLastDates = const {};
    _currentLat = null;
    _currentLng = null;
    _currentLocationLabel = '';
    _currentStationName = defaultStationName;
    _guardianShareFrequency = 'manual';
    _needsRegistration = false;
    _authToken = '';
    _errorMessage = null;
    _api.clear();
    if (!keepBaseUrl) {
      _baseUrl = defaultBaseUrl;
    }
  }

  Future<T> _safeLoad<T>(
    Future<T> Function() loader, {
    required T fallback,
  }) async {
    try {
      return await loader();
    } on ApiException catch (error) {
      _errorMessage ??= error.message;
      return fallback;
    }
  }

  String _extractExtension(String fileName) {
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == fileName.length - 1) {
      return 'mp3';
    }
    return fileName.substring(dotIndex + 1).toLowerCase();
  }

  String _todayStatusKey() {
    final now = DateTime.now();
    final year = now.year.toString().padLeft(4, '0');
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '$_scheduleStatusPrefix$year-$month-$day';
  }

  Map<String, bool> _emptyDoseStatus() => const {
        'morning': false,
        'afternoon': false,
        'evening': false,
        'bedtime': false,
      };

  Future<void> _restoreScheduleDoseStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_todayStatusKey());
    if (raw == null || raw.isEmpty) {
      _scheduleDoseStatus = {
        for (final schedule in _schedules) schedule.id: _emptyDoseStatus(),
      };
      return;
    }

    try {
      final decoded = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final restored = <int, Map<String, bool>>{};
      for (final schedule in _schedules) {
        final saved = decoded['${schedule.id}'];
        if (saved is Map) {
          restored[schedule.id] = {
            'morning': saved['morning'] == true,
            'afternoon': saved['afternoon'] == true,
            'evening': saved['evening'] == true,
            'bedtime': saved['bedtime'] == true,
          };
        } else {
          restored[schedule.id] = _emptyDoseStatus();
        }
      }
      _scheduleDoseStatus = restored;
    } catch (_) {
      _scheduleDoseStatus = {
        for (final schedule in _schedules) schedule.id: _emptyDoseStatus(),
      };
    }
  }

  Future<void> _persistScheduleDoseStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = {
      for (final entry in _scheduleDoseStatus.entries) '${entry.key}': entry.value,
    };
    await prefs.setString(_todayStatusKey(), jsonEncode(payload));
  }

  String _doseLabelFromKey(String doseKey) {
    switch (doseKey) {
      case 'morning':
        return '아침';
      case 'afternoon':
        return '점심';
      case 'evening':
        return '저녁';
      case 'bedtime':
        return '취침 전';
      default:
        return doseKey;
    }
  }

  Future<void> _autoShareDoctorNoteIfNeeded(int doctorNoteId) async {
    if (!_canAutoShare('doctor_note')) {
      return;
    }
    try {
      await _api.notifyGuardian(doctorNoteId);
      await _markAutoShared('doctor_note');
    } catch (_) {}
  }

  Future<void> _autoShareSymptomIfNeeded(int symptomId) async {
    if (!_canAutoShare('symptom')) {
      return;
    }
    try {
      await _api.notifyGuardianForSymptom(symptomId);
      await _markAutoShared('symptom');
    } catch (_) {}
  }

  Future<void> _autoShareDoseIfNeeded({
    required int scheduleId,
    required String doseLabel,
    required bool completed,
  }) async {
    if (!_canAutoShare('dose')) {
      return;
    }
    try {
      await _api.notifyGuardianForDose(
        scheduleId: scheduleId,
        doseLabel: doseLabel,
        completed: completed,
      );
      await _markAutoShared('dose');
    } catch (_) {}
  }

  bool _canAutoShare(String channel) {
    if (!isLoggedIn) {
      return false;
    }
    if (_currentUser?.guardianPhone.isEmpty != false) {
      return false;
    }
    if (_guardianShareFrequency == 'manual') {
      return false;
    }
    if (_guardianShareFrequency == 'always') {
      return true;
    }
    if (_guardianShareFrequency == 'daily') {
      return _isDailyAutoShareAvailable(channel);
    }
    return false;
  }

  Future<void> _markAutoShared(String channel) async {
    if (_guardianShareFrequency == 'daily') {
      final prefs = await SharedPreferences.getInstance();
      final today = _todayDateLabel();
      await prefs.setString(
        '$_guardianShareLastPrefix$channel',
        today,
      );
      _guardianShareLastDates = {
        ..._guardianShareLastDates,
        channel: today,
      };
    }
  }

  Future<void> refreshAll() async {
    if (!isLoggedIn) {
      return;
    }

    if (_guardianShareFrequency == 'daily') {
      final prefs = await SharedPreferences.getInstance();
      final today = _todayDateLabel();
      for (final channel in ['doctor_note', 'symptom', 'dose']) {
        final saved = prefs.getString('$_guardianShareLastPrefix$channel');
        if (saved != null && saved.isNotEmpty && saved != today) {
          await prefs.remove('$_guardianShareLastPrefix$channel');
          _guardianShareLastDates = {
            ..._guardianShareLastDates,
            channel: '',
          };
        }
      }
    }

    await _runBusy(() async {
      await _loadInitialData();
    });
  }

  bool _isDailyAutoShareAvailable(String channel) {
    return _guardianShareLastDates[channel] != _todayDateLabel();
  }

  String _todayDateLabel() {
    final now = DateTime.now();
    final year = now.year.toString().padLeft(4, '0');
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
