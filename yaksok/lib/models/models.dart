class UserModel {
  final int id;
  final String name;
  final String nickname;
  final String email;
  final String guardianEmail;
  final int age;
  final String gender;
  final String address;
  final String profileImage;
  final bool isRegistered;
  final DateTime? createdAt;

  const UserModel({
    required this.id,
    required this.name,
    required this.nickname,
    required this.email,
    required this.guardianEmail,
    required this.age,
    required this.gender,
    required this.address,
    required this.profileImage,
    required this.isRegistered,
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: _asInt(json['id']),
      name: _asString(json['name']),
      nickname: _asString(json['nickname']),
      email: _asString(json['email']),
      guardianEmail: _asString(json['guardian_email']),
      age: _asInt(json['age']),
      gender: _asString(json['gender']),
      address: _asString(json['address']),
      profileImage: _asString(json['profile_image']),
      isRegistered: json['is_registered'] == true || json['is_registered'] == 1,
      createdAt: _asDateTime(json['created_at']),
    );
  }
}

class MedicineSchedule {
  final int id;
  final String medicineName;
  final List<String> schedule;
  final String scheduleText;
  final String caution;
  final bool isActive;
  final int? noteId;
  final DateTime? createdAt;

  const MedicineSchedule({
    required this.id,
    required this.medicineName,
    required this.schedule,
    required this.scheduleText,
    required this.caution,
    required this.isActive,
    required this.noteId,
    required this.createdAt,
  });

  String get displaySchedule =>
      scheduleText.isNotEmpty ? scheduleText : schedule.join(', ');

  factory MedicineSchedule.fromJson(Map<String, dynamic> json) {
    return MedicineSchedule(
      id: _asInt(json['id']),
      medicineName: _asString(json['medicine_name']),
      schedule: _asStringList(json['schedule']),
      scheduleText: _asString(json['schedule_text']),
      caution: _asString(json['caution']),
      isActive: json['is_active'] == true || json['is_active'] == 1,
      noteId: json['note_id'] == null ? null : _asInt(json['note_id']),
      createdAt: _asDateTime(json['created_at']),
    );
  }
}

class PossibleDisease {
  final String name;
  final String reason;

  const PossibleDisease({
    required this.name,
    required this.reason,
  });

  factory PossibleDisease.fromJson(Map<String, dynamic> json) {
    return PossibleDisease(
      name: _asString(json['name']),
      reason: _asString(json['reason']),
    );
  }
}

class SymptomAnalysis {
  final int id;
  final String symptom;
  final List<PossibleDisease> possibleDiseases;
  final bool isEmergency;
  final String emergencyMessage;
  final String disclaimer;
  final DateTime? createdAt;

  const SymptomAnalysis({
    required this.id,
    required this.symptom,
    required this.possibleDiseases,
    required this.isEmergency,
    required this.emergencyMessage,
    required this.disclaimer,
    required this.createdAt,
  });

  factory SymptomAnalysis.fromJson(Map<String, dynamic> json) {
    return SymptomAnalysis(
      id: _asInt(json['id']),
      symptom: _asString(json['symptom']),
      possibleDiseases: _asMapList(json['possible_diseases'])
          .map(PossibleDisease.fromJson)
          .toList(),
      isEmergency: json['is_emergency'] == true || json['is_emergency'] == 1,
      emergencyMessage: _asString(json['emergency_message']),
      disclaimer: _asString(json['disclaimer']),
      createdAt:
          _asDateTime(json['analyzed_at']) ?? _asDateTime(json['created_at']),
    );
  }
}

class DoctorMedication {
  final String name;
  final String schedule;
  final String caution;

  const DoctorMedication({
    required this.name,
    required this.schedule,
    required this.caution,
  });

  factory DoctorMedication.fromJson(Map<String, dynamic> json) {
    return DoctorMedication(
      name: _asString(json['name']),
      schedule: _asString(json['schedule']),
      caution: _asString(json['caution']),
    );
  }
}

class DoctorNoteSummary {
  final String diagnosis;
  final List<DoctorMedication> medications;
  final List<String> precautions;
  final String nextVisit;
  final String summary;

  const DoctorNoteSummary({
    required this.diagnosis,
    required this.medications,
    required this.precautions,
    required this.nextVisit,
    required this.summary,
  });

  factory DoctorNoteSummary.fromJson(Map<String, dynamic> json) {
    return DoctorNoteSummary(
      diagnosis: _asString(json['diagnosis']),
      medications: _asMapList(json['medications'])
          .map(DoctorMedication.fromJson)
          .toList(),
      precautions: _asStringList(json['precautions']),
      nextVisit: _asString(json['next_visit']),
      summary: _asString(json['summary']),
    );
  }
}

class DoctorNote {
  final int id;
  final DateTime? visitDate;
  final String originalText;
  final DoctorNoteSummary summaryData;
  final DateTime? createdAt;

  const DoctorNote({
    required this.id,
    required this.visitDate,
    required this.originalText,
    required this.summaryData,
    required this.createdAt,
  });

  String get summary => summaryData.summary.isNotEmpty
      ? summaryData.summary
      : summaryData.diagnosis;

  factory DoctorNote.fromJson(Map<String, dynamic> json) {
    final summaryJson = json['summary'];
    return DoctorNote(
      id: _asInt(json['id']),
      visitDate: _asDateTime(json['visit_date']),
      originalText: _asString(json['original_text']),
      summaryData: DoctorNoteSummary.fromJson(
        summaryJson is Map<String, dynamic> ? summaryJson : <String, dynamic>{},
      ),
      createdAt: _asDateTime(json['created_at']),
    );
  }
}

class PresignedUploadInfo {
  final String uploadUrl;
  final String s3Key;
  final String fileUrl;
  final int expiresIn;
  final String contentType;

  const PresignedUploadInfo({
    required this.uploadUrl,
    required this.s3Key,
    required this.fileUrl,
    required this.expiresIn,
    required this.contentType,
  });

  factory PresignedUploadInfo.fromJson(Map<String, dynamic> json) {
    return PresignedUploadInfo(
      uploadUrl: _asString(json['upload_url']),
      s3Key: _asString(json['s3_key']),
      fileUrl: _asString(json['file_url']),
      expiresIn: _asInt(json['expires_in']),
      contentType: _asString(json['content_type']),
    );
  }
}

class DiseaseTrend {
  final int rank;
  final String name;
  final String grade;
  final int count;
  final String region;
  final String year;

  const DiseaseTrend({
    required this.rank,
    required this.name,
    required this.grade,
    required this.count,
    required this.region,
    required this.year,
  });

  factory DiseaseTrend.fromJson(Map<String, dynamic> json) {
    return DiseaseTrend(
      rank: _asInt(json['rank']),
      name: _asString(json['name']),
      grade: _asString(json['grade']),
      count: _asInt(json['count']),
      region: _asString(json['region']),
      year: _asString(json['year']),
    );
  }
}

class DiseaseSnapshot {
  final String source;
  final String year;
  final int totalDiseases;
  final String notice;
  final List<DiseaseTrend> topDiseases;

  const DiseaseSnapshot({
    required this.source,
    required this.year,
    required this.totalDiseases,
    required this.notice,
    required this.topDiseases,
  });

  factory DiseaseSnapshot.fromJson(Map<String, dynamic> json) {
    return DiseaseSnapshot(
      source: _asString(json['source']),
      year: _asString(json['year']),
      totalDiseases: _asInt(json['total_diseases']),
      notice: _asString(json['notice']),
      topDiseases: _asMapList(json['top_diseases'])
          .map(DiseaseTrend.fromJson)
          .toList(),
    );
  }
}

class MedicineRecommendation {
  final String name;
  final String efficacy;
  final String howToTake;
  final String caution;

  const MedicineRecommendation({
    required this.name,
    required this.efficacy,
    required this.howToTake,
    required this.caution,
  });

  factory MedicineRecommendation.fromJson(Map<String, dynamic> json) {
    return MedicineRecommendation(
      name: _asString(json['name']),
      efficacy: _asString(json['efficacy']),
      howToTake: _asString(json['how_to_take']),
      caution: _asString(json['caution']),
    );
  }
}

class MedicineSearchRecord {
  final int id;
  final String input;
  final List<MedicineRecommendation> recommendations;
  final String disclaimer;
  final DateTime? createdAt;

  const MedicineSearchRecord({
    required this.id,
    required this.input,
    required this.recommendations,
    required this.disclaimer,
    required this.createdAt,
  });

  factory MedicineSearchRecord.fromJson(Map<String, dynamic> json) {
    return MedicineSearchRecord(
      id: _asInt(json['id']),
      input: _asString(json['input']),
      recommendations: _asMapList(json['recommendations'])
          .map(MedicineRecommendation.fromJson)
          .toList(),
      disclaimer: _asString(json['disclaimer']),
      createdAt:
          _asDateTime(json['searched_at']) ?? _asDateTime(json['created_at']),
    );
  }
}

class AirQualityMetric {
  final String value;
  final String grade;
  final String emoji;

  const AirQualityMetric({
    required this.value,
    required this.grade,
    required this.emoji,
  });

  factory AirQualityMetric.fromJson(Map<String, dynamic> json) {
    return AirQualityMetric(
      value: _asString(json['value']),
      grade: _asString(json['grade']),
      emoji: _asString(json['emoji']),
    );
  }
}

class AirQualityInfo {
  final String stationName;
  final String measuredAt;
  final AirQualityMetric pm10;
  final AirQualityMetric pm25;
  final AirQualityMetric khai;
  final String o3;
  final String no2;

  const AirQualityInfo({
    required this.stationName,
    required this.measuredAt,
    required this.pm10,
    required this.pm25,
    required this.khai,
    required this.o3,
    required this.no2,
  });

  factory AirQualityInfo.fromJson(Map<String, dynamic> json) {
    return AirQualityInfo(
      stationName: _asString(json['station_name']),
      measuredAt: _asString(json['measured_at']),
      pm10: AirQualityMetric.fromJson(
        json['pm10'] is Map<String, dynamic> ? json['pm10'] : {},
      ),
      pm25: AirQualityMetric.fromJson(
        json['pm25'] is Map<String, dynamic> ? json['pm25'] : {},
      ),
      khai: AirQualityMetric.fromJson(
        json['khai'] is Map<String, dynamic> ? json['khai'] : {},
      ),
      o3: _asString(json['o3']),
      no2: _asString(json['no2']),
    );
  }
}

class WeatherInfo {
  final String forecastTime;
  final String temperature;
  final String tempMax;
  final String tempMin;
  final String sky;
  final String precipitationType;
  final String precipitationProbability;
  final String humidity;
  final String windSpeed;

  const WeatherInfo({
    required this.forecastTime,
    required this.temperature,
    required this.tempMax,
    required this.tempMin,
    required this.sky,
    required this.precipitationType,
    required this.precipitationProbability,
    required this.humidity,
    required this.windSpeed,
  });

  factory WeatherInfo.fromJson(Map<String, dynamic> json) {
    return WeatherInfo(
      forecastTime: _asString(json['fcst_time']),
      temperature: _asString(json['temperature']),
      tempMax: _asString(json['temp_max']),
      tempMin: _asString(json['temp_min']),
      sky: _asString(json['sky']),
      precipitationType: _asString(json['precipitation_type']),
      precipitationProbability: _asString(json['precipitation_prob']),
      humidity: _asString(json['humidity']),
      windSpeed: _asString(json['wind_speed']),
    );
  }
}

class WeatherSnapshot {
  final WeatherInfo? weather;
  final AirQualityInfo? airQuality;
  final List<String> healthAdvice;
  final DateTime? updatedAt;

  const WeatherSnapshot({
    required this.weather,
    required this.airQuality,
    required this.healthAdvice,
    required this.updatedAt,
  });

  factory WeatherSnapshot.fromJson(Map<String, dynamic> json) {
    return WeatherSnapshot(
      weather: json['weather'] is Map<String, dynamic>
          ? WeatherInfo.fromJson(json['weather'])
          : null,
      airQuality: json['air_quality'] is Map<String, dynamic>
          ? AirQualityInfo.fromJson(json['air_quality'])
          : null,
      healthAdvice: _asStringList(json['health_advice']),
      updatedAt: _asDateTime(json['updated_at']),
    );
  }
}

class Pharmacy {
  final int rank;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String phone;
  final String distanceLabel;
  final int distanceMeters;
  final String kakaoUrl;

  const Pharmacy({
    required this.rank,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.phone,
    required this.distanceLabel,
    required this.distanceMeters,
    required this.kakaoUrl,
  });

  factory Pharmacy.fromJson(Map<String, dynamic> json) {
    return Pharmacy(
      rank: _asInt(json['rank']),
      name: _asString(json['name']),
      address: _asString(json['address']),
      latitude: _asDouble(json['lat']),
      longitude: _asDouble(json['lng']),
      phone: _asString(json['phone']),
      distanceLabel: _asString(json['distance']),
      distanceMeters: _asInt(json['distance_m']),
      kakaoUrl: _asString(json['kakao_url']),
    );
  }
}

DateTime? _asDateTime(dynamic value) {
  if (value == null) {
    return null;
  }
  return DateTime.tryParse(value.toString());
}

int _asInt(dynamic value) {
  if (value == null) {
    return 0;
  }
  if (value is int) {
    return value;
  }
  return int.tryParse(value.toString()) ?? 0;
}

double _asDouble(dynamic value) {
  if (value == null) {
    return 0;
  }
  if (value is double) {
    return value;
  }
  if (value is int) {
    return value.toDouble();
  }
  return double.tryParse(value.toString()) ?? 0;
}

String _asString(dynamic value) {
  if (value == null) {
    return '';
  }
  return value.toString();
}

List<String> _asStringList(dynamic value) {
  if (value is! List) {
    return const [];
  }
  return value.map((item) => item.toString()).toList();
}

List<Map<String, dynamic>> _asMapList(dynamic value) {
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
