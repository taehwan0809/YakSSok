import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/models.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class RegistrationRequiredException extends ApiException {
  const RegistrationRequiredException(super.message, {super.statusCode});
}

class BackendApi {
  String _baseUrl = '';
  String _token = '';

  String get baseUrl => _baseUrl;
  String get token => _token;
  bool get isConfigured => _baseUrl.isNotEmpty && _token.isNotEmpty;

  void configure({
    required String baseUrl,
    required String token,
  }) {
    _baseUrl = _normalizeBaseUrl(baseUrl);
    _token = token.trim();
  }

  void clear() {
    _baseUrl = '';
    _token = '';
  }

  Future<String> fetchKakaoAuthUrl(String baseUrl) async {
    final response = await http
        .get(_buildUri(baseUrl, '/auth/kakao'))
        .timeout(
          const Duration(seconds: 8),
          onTimeout: () => throw const ApiException('서버 응답 시간이 초과되었습니다. 백엔드가 실행 중인지 확인하세요.'),
        );
    final body = _decodeBody(response);
    _ensureSuccess(response, body);
    return body['auth_url']?.toString() ?? '';
  }

  Future<UserModel> fetchMe() async {
    final body = await _request('GET', '/auth/me');
    return UserModel.fromJson(_asMap(body['user']));
  }

  Future<UserModel> register({
    required String name,
    required int age,
    required String gender,
    required String address,
    String guardianEmail = '',
    String guardianPhone = '',
  }) async {
    final body = await _request(
      'POST',
      '/auth/register',
      payload: {
        'name': name,
        'age': age,
        'gender': gender,
        'address': address,
        if (guardianEmail.trim().isNotEmpty) 'guardian_email': guardianEmail.trim(),
        if (guardianPhone.trim().isNotEmpty) 'guardian_phone': guardianPhone.trim(),
      },
    );
    final nextToken = body['token']?.toString();
    if (nextToken != null && nextToken.isNotEmpty) {
      _token = nextToken;
    }
    return UserModel.fromJson(_asMap(body['user']));
  }

  Future<UserModel> updateProfile({
    required String name,
    required int age,
    required String gender,
    required String address,
    String guardianEmail = '',
    String guardianPhone = '',
  }) async {
    final body = await _request(
      'PUT',
      '/auth/profile',
      payload: {
        'name': name,
        'age': age,
        'gender': gender,
        'address': address,
        'guardian_email': guardianEmail.trim(),
        'guardian_phone': guardianPhone.trim(),
      },
    );
    return UserModel.fromJson(_asMap(body['user']));
  }

  Future<void> logout() async {
    if (!isConfigured) {
      return;
    }
    await _request('POST', '/auth/logout');
  }

  Future<String> updateGuardianPhone(String guardianPhone) async {
    final body = await _request(
      'PUT',
      '/auth/guardian',
      payload: {'guardian_phone': guardianPhone},
    );
    return body['message']?.toString() ?? '보호자 연락처가 저장되었습니다.';
  }

  Future<String> notifyGuardian(int doctorNoteId) async {
    final body = await _request('POST', '/doctor-note/$doctorNoteId/notify');
    return body['message']?.toString() ?? '보호자에게 알림을 발송했습니다.';
  }

  Future<String> notifyGuardianForSymptom(int symptomId) async {
    final body = await _request('POST', '/symptom/$symptomId/notify');
    return body['message']?.toString() ?? '보호자에게 증상 분석 알림을 발송했습니다.';
  }

  Future<String> notifyGuardianForDose({
    required int scheduleId,
    required String doseLabel,
    required bool completed,
  }) async {
    final body = await _request(
      'POST',
      '/schedule/$scheduleId/notify-dose',
      payload: {
        'dose_label': doseLabel,
        'completed': completed,
      },
    );
    return body['message']?.toString() ?? '보호자에게 복용 상태 알림을 발송했습니다.';
  }

  Future<List<MedicineSchedule>> fetchSchedules({bool activeOnly = false}) async {
    final body = await _request(
      'GET',
      '/schedule',
      query: activeOnly ? {'active': 'true'} : null,
    );
    return _asList(body['data']).map(MedicineSchedule.fromJson).toList();
  }

  Future<MedicineSchedule> createSchedule({
    required String medicineName,
    required String scheduleText,
    String caution = '',
  }) async {
    final body = await _request(
      'POST',
      '/schedule',
      payload: {
        'medicine_name': medicineName,
        'schedule_text': scheduleText,
        'caution': caution,
      },
    );
    return MedicineSchedule.fromJson(_asMap(body['data']));
  }

  Future<MedicineSchedule> updateSchedule({
    required int id,
    String? medicineName,
    String? scheduleText,
    String? caution,
    bool? isActive,
  }) async {
    final body = await _request(
      'PUT',
      '/schedule/$id',
      payload: {
        if (medicineName != null) 'medicine_name': medicineName,
        if (scheduleText != null) 'schedule_text': scheduleText,
        if (caution != null) 'caution': caution,
        if (isActive != null) 'is_active': isActive,
      },
    );
    return MedicineSchedule.fromJson(_asMap(body['data']));
  }

  Future<void> deleteSchedule(int id) async {
    await _request('DELETE', '/schedule/$id');
  }

  Future<List<DoctorNote>> fetchDoctorNotes({int limit = 20}) async {
    final body = await _request(
      'GET',
      '/doctor-note',
      query: {'limit': '$limit'},
    );
    return _asList(body['data']).map(DoctorNote.fromJson).toList();
  }

  Future<DoctorNote> fetchDoctorNoteDetail(int id) async {
    final body = await _request('GET', '/doctor-note/$id');
    return DoctorNote.fromJson(_asMap(body['data']));
  }

  Future<PresignedUploadInfo> getDoctorNotePresignedUrl(String extension) async {
    final body = await _request(
      'GET',
      '/doctor-note/presigned-url',
      query: {'ext': extension},
    );
    return PresignedUploadInfo.fromJson(_asMap(body['data']));
  }

  Future<void> uploadFileToPresignedUrl({
    required String uploadUrl,
    required String contentType,
    required Uint8List bytes,
  }) async {
    final response = await http.put(
      Uri.parse(uploadUrl),
      headers: {'Content-Type': contentType},
      body: bytes,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'S3 업로드에 실패했습니다.',
        statusCode: response.statusCode,
      );
    }
  }

  Future<DoctorNote> processDoctorNote({
    required String s3Key,
    String? visitDate,
  }) async {
    final body = await _request(
      'POST',
      '/doctor-note/process',
      payload: {
        's3_key': s3Key,
        if (visitDate != null && visitDate.isNotEmpty) 'visit_date': visitDate,
      },
    );
    return DoctorNote.fromJson(_asMap(body['data']));
  }

  Future<SymptomAnalysis> analyzeSymptom(String symptom) async {
    final body = await _request(
      'POST',
      '/symptom',
      payload: {'symptom': symptom},
    );
    return SymptomAnalysis.fromJson(_asMap(body['data']));
  }

  Future<List<SymptomAnalysis>> fetchSymptomHistory({int limit = 20}) async {
    final body = await _request(
      'GET',
      '/symptom/history',
      query: {'limit': '$limit'},
    );
    return _asList(body['data']).map(SymptomAnalysis.fromJson).toList();
  }

  Future<MedicineSearchRecord> recommendMedicine(String input) async {
    final body = await _request(
      'POST',
      '/medicine/recommend',
      payload: {'input': input},
    );
    return MedicineSearchRecord.fromJson(_asMap(body['data']));
  }

  Future<List<MedicineSearchRecord>> fetchMedicineHistory({int limit = 20}) async {
    final body = await _request(
      'GET',
      '/medicine/history',
      query: {'limit': '$limit'},
    );
    return _asList(body['data']).map(MedicineSearchRecord.fromJson).toList();
  }

  Future<DiseaseSnapshot> fetchDiseases({
    required String region,
    int limit = 5,
  }) async {
    final body = await _request(
      'GET',
      '/disease',
      query: {
        'region': region,
        'limit': '$limit',
      },
    );
    return DiseaseSnapshot.fromJson(_asMap(body['data']));
  }

  Future<WeatherSnapshot> fetchWeather({
    required double lat,
    required double lng,
    required String stationName,
  }) async {
    final body = await _request(
      'GET',
      '/weather',
      query: {
        'lat': '$lat',
        'lng': '$lng',
        'stationName': stationName,
      },
    );
    return WeatherSnapshot.fromJson(_asMap(body['data']));
  }

  Future<List<Pharmacy>> fetchNearbyPharmacies({
    required double lat,
    required double lng,
    int radius = 1000,
    int size = 15,
  }) async {
    final body = await _request(
      'GET',
      '/pharmacy',
      query: {
        'lat': '$lat',
        'lng': '$lng',
        'radius': '$radius',
        'size': '$size',
      },
    );
    final data = _asMap(body['data']);
    return _asList(data['pharmacies']).map(Pharmacy.fromJson).toList();
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? payload,
  }) async {
    if (!isConfigured) {
      throw const ApiException('백엔드 주소와 토큰이 필요합니다.');
    }

    final uri = Uri.parse('$_baseUrl$path').replace(queryParameters: query);
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_token',
    };

    const timeout = Duration(seconds: 15);
    late final http.Response response;
    switch (method) {
      case 'GET':
        response = await http.get(uri, headers: headers).timeout(timeout);
        break;
      case 'POST':
        response = await http
            .post(uri, headers: headers, body: jsonEncode(payload))
            .timeout(timeout);
        break;
      case 'PUT':
        response = await http
            .put(uri, headers: headers, body: jsonEncode(payload))
            .timeout(timeout);
        break;
      case 'DELETE':
        response = await http.delete(uri, headers: headers).timeout(timeout);
        break;
      default:
        throw ApiException('지원하지 않는 메서드입니다: $method');
    }

    final body = _decodeBody(response);
    _ensureSuccess(response, body);
    return body;
  }

  Map<String, dynamic> _decodeBody(http.Response response) {
    if (response.body.isEmpty) {
      return const {};
    }

    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw ApiException('응답 형식이 올바르지 않습니다.', statusCode: response.statusCode);
  }

  void _ensureSuccess(http.Response response, Map<String, dynamic> body) {
    if (response.statusCode >= 200 &&
        response.statusCode < 300 &&
        body['success'] != false) {
      return;
    }

    final message = body['message']?.toString() ?? '요청 처리에 실패했습니다.';
    if (response.statusCode == 403 && message.contains('추가 정보 입력')) {
      throw RegistrationRequiredException(message, statusCode: response.statusCode);
    }
    throw ApiException(message, statusCode: response.statusCode);
  }

  static Uri _buildUri(String baseUrl, String path) {
    return Uri.parse('${_normalizeBaseUrl(baseUrl)}$path');
  }

  static String _normalizeBaseUrl(String baseUrl) {
    return baseUrl.trim().replaceFirst(RegExp(r'/$'), '');
  }
}

List<Map<String, dynamic>> _asList(dynamic value) {
  if (value is! List) {
    return const [];
  }
  return value
      .whereType<Map>()
      .map((item) => item.map(
            (key, val) => MapEntry(key.toString(), val),
          ))
      .toList();
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, val) => MapEntry(key.toString(), val));
  }
  return const {};
}
