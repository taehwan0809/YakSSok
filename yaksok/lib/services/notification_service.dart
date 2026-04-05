import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/models.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'medicine_reminder';
  static const String _channelName = '약 복용 알림';

  // 복용 시간대별 시각
  static const Map<String, int> _doseHours = {
    'morning': 8,
    'afternoon': 12,
    'evening': 18,
    'bedtime': 21,
  };

  static const Map<String, String> _doseKeys = {
    '아침': 'morning',
    '점심': 'afternoon',
    '저녁': 'evening',
    '취침 전': 'bedtime',
  };

  static const Map<String, int> _doseIndex = {
    'morning': 0,
    'afternoon': 1,
    'evening': 2,
    'bedtime': 3,
  };

  static Future<void> init() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );

    // Android 알림 채널 생성
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: '약 복용 시간을 알려드립니다.',
      importance: Importance.high,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  static Future<void> requestPermission() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  /// 모든 일정 알림 재설정 (앱 시작 / 일정 변경 시 호출)
  static Future<void> rescheduleAll(List<MedicineSchedule> schedules) async {
    await _plugin.cancelAll();
    for (final s in schedules) {
      if (s.isActive) {
        await _scheduleForMedicine(s);
      }
    }
  }

  /// 특정 일정 알림 취소
  static Future<void> cancelForSchedule(int scheduleId) async {
    for (int i = 0; i < 4; i++) {
      await _plugin.cancel(_notifId(scheduleId, i));
    }
  }

  static int _notifId(int scheduleId, int doseIdx) => scheduleId * 4 + doseIdx;

  static Future<void> _scheduleForMedicine(MedicineSchedule schedule) async {
    for (final label in schedule.schedule) {
      final key = _doseKeys[label];
      if (key == null) continue;
      final hour = _doseHours[key]!;
      final idx = _doseIndex[key]!;
      final notifId = _notifId(schedule.id, idx);

      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate = tz.TZDateTime(
          tz.local, now.year, now.month, now.day, hour, 0);
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      // 종료일이 지났으면 스킵
      if (schedule.endDate != null) {
        final endTz = tz.TZDateTime.from(
          DateTime(schedule.endDate!.year, schedule.endDate!.month,
              schedule.endDate!.day, 23, 59),
          tz.local,
        );
        if (scheduledDate.isAfter(endTz)) continue;
      }

      const androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: '약 복용 시간을 알려드립니다.',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );
      const iosDetails = DarwinNotificationDetails();
      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      if (schedule.endDate != null) {
        // 종료일까지 개별 스케줄링 (최대 30일)
        var date = scheduledDate;
        final endTz = tz.TZDateTime.from(
          DateTime(schedule.endDate!.year, schedule.endDate!.month,
              schedule.endDate!.day, hour, 0),
          tz.local,
        );
        int dayOffset = 0;
        while (!date.isAfter(endTz) && dayOffset < 30) {
          final perDayId = notifId * 31 + dayOffset;
          await _plugin.zonedSchedule(
            perDayId,
            '약 복용 시간 💊',
            '${schedule.medicineName} $label 복용 시간입니다.',
            date,
            details,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
          );
          date = date.add(const Duration(days: 1));
          dayOffset++;
        }
      } else {
        // 무기한: 매일 반복
        await _plugin.zonedSchedule(
          notifId,
          '약 복용 시간 💊',
          '${schedule.medicineName} $label 복용 시간입니다.',
          scheduledDate,
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      }
    }
  }
}
