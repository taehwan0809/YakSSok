import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../services/backend_api.dart';

class AppProvider extends ChangeNotifier {
  static const String _baseUrlKey = 'backend_base_url';
  static const String _tokenKey = 'backend_token';

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
  }) async {
    await _runBusy(() async {
      _errorMessage = null;
      final user = await _api.register(
        name: name,
        age: age,
        gender: gender,
        address: address,
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

  Future<void> refreshAll() async {
    if (!isLoggedIn) {
      return;
    }
    await _runBusy(() async {
      await _loadInitialData();
    });
  }

  Future<void> refreshSchedules() async {
    if (!isLoggedIn) {
      return;
    }
    _schedules = await _safeLoad(() => _api.fetchSchedules(), fallback: _schedules);
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
    double lat = defaultLat,
    double lng = defaultLng,
    String stationName = defaultStationName,
  }) async {
    if (!isLoggedIn) {
      return;
    }
    _weatherSnapshot = await _safeLoad(
      () => _api.fetchWeather(
        lat: lat,
        lng: lng,
        stationName: stationName,
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
    double lat = defaultLat,
    double lng = defaultLng,
    int radius = 1000,
  }) async {
    if (!isLoggedIn) {
      return;
    }
    _pharmacies = await _safeLoad(
      () => _api.fetchNearbyPharmacies(
        lat: lat,
        lng: lng,
        radius: radius,
      ),
      fallback: _pharmacies,
    );
    notifyListeners();
  }

  Future<MedicineSearchRecord> recommendMedicine(String input) async {
    final result = await _api.recommendMedicine(input);
    _medicineHistory = [result, ..._medicineHistory];
    notifyListeners();
    return result;
  }

  Future<SymptomAnalysis> analyzeSymptom(String symptom) async {
    final result = await _api.analyzeSymptom(symptom);
    _symptomHistory = [result, ..._symptomHistory];
    notifyListeners();
    return result;
  }

  Future<void> addSchedule({
    required String medicineName,
    required String scheduleText,
    String caution = '',
  }) async {
    final created = await _api.createSchedule(
      medicineName: medicineName,
      scheduleText: scheduleText,
      caution: caution,
    );
    _schedules = [created, ..._schedules];
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
    notifyListeners();
  }

  Future<DoctorNote> loadDoctorNoteDetail(int id) {
    return _api.fetchDoctorNoteDetail(id);
  }

  Future<String> fetchKakaoAuthUrl(String baseUrl) {
    return _api.fetchKakaoAuthUrl(baseUrl.trim().isEmpty ? defaultBaseUrl : baseUrl);
  }

  Future<void> _restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString(_baseUrlKey) ?? defaultBaseUrl;
    _authToken = prefs.getString(_tokenKey) ?? '';

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
        lat: defaultLat,
        lng: defaultLng,
        stationName: defaultStationName,
      ),
      fallback: null,
    );
    _diseaseSnapshot = await _safeLoad(
      () => _api.fetchDiseases(region: defaultRegion),
      fallback: null,
    );
    _pharmacies = await _safeLoad(
      () => _api.fetchNearbyPharmacies(
        lat: defaultLat,
        lng: defaultLng,
        radius: 1200,
      ),
      fallback: const [],
    );
  }

  Future<void> _persistSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, _baseUrl);
    await prefs.setString(_tokenKey, _authToken);
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
}
