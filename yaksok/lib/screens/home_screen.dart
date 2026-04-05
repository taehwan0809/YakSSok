import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'diseases_screen.dart';
import 'doctor_notes_screen.dart';
import 'medicine_search_screen.dart';
import 'pharmacy_map_screen.dart';
import 'symptoms_screen.dart';
import 'weather_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final user = app.currentUser;
    final weather = app.weatherSnapshot?.weather;
    final air = app.weatherSnapshot?.airQuality;
    final activeSchedules = app.schedules.where((item) => item.isActive).toList();
    final schedules = (activeSchedules.isNotEmpty ? activeSchedules : app.schedules)
        .take(2)
        .toList();
    final latestNote = app.doctorNotes.isNotEmpty ? app.doctorNotes.first : null;
    final trendingDisease = app.diseaseSnapshot?.topDiseases.isNotEmpty == true
        ? app.diseaseSnapshot!.topDiseases.first
        : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: app.refreshAll,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _greeting(),
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      '${user?.name.isNotEmpty == true ? user!.name : '사용자'}님',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primaryBlue,
                  child: Text(
                    (user?.name.isNotEmpty == true ? user!.name[0] : 'U').toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WeatherScreen()),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.darkBlue, AppColors.primaryBlue],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '오늘의 날씨',
                            style: TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            app.currentLocationLabel,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            weather == null
                                ? '날씨 정보 불러오는 중'
                                : '${weather.temperature} ${weather.sky}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              air == null
                                  ? '대기질 정보 없음'
                                  : '${air.stationName} 미세먼지 ${air.pm10.grade}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.wb_sunny_rounded,
                      color: Colors.white,
                      size: 64,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const SectionHeader(title: '빠른 메뉴'),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                QuickActionButton(
                  icon: Icons.sick_outlined,
                  label: '증상 분석',
                  color: const Color(0xFFE53935),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SymptomsScreen()),
                  ),
                ),
                QuickActionButton(
                  icon: Icons.coronavirus_outlined,
                  label: '유행 질병',
                  color: const Color(0xFFFB8C00),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DiseasesScreen()),
                  ),
                ),
                QuickActionButton(
                  icon: Icons.medication_outlined,
                  label: '약 추천/사용법',
                  color: const Color(0xFF43A047),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MedicineSearchScreen(),
                    ),
                  ),
                ),
                QuickActionButton(
                  icon: Icons.local_pharmacy_outlined,
                  label: '약국 찾기',
                  color: const Color(0xFF8E24AA),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PharmacyMapScreen(),
                    ),
                  ),
                ),
              ],
            ),
            // 수동 전송 모드일 때만 홈에 버튼 표시
            if (app.isLoggedIn &&
                app.currentUser?.guardianPhone.isNotEmpty == true &&
                app.guardianShareFrequency == 'manual') ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: app.isBusy
                      ? null
                      : () async {
                          try {
                            final message = await context.read<AppProvider>().notifyHealthSummary();
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(message)),
                            );
                          } catch (error) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(error.toString())),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.sms_outlined),
                  label: const Text('보호자에게 건강 알림 보내기', style: TextStyle(fontSize: 15)),
                ),
              ),
            ],
            const SizedBox(height: 28),
            const SectionHeader(title: '복용 일정'),
            const SizedBox(height: 12),
            if (schedules.isEmpty)
              const YakSokCard(
                child: Text(
                  '활성화된 복용 일정이 없습니다.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              )
            else
              ...schedules.map(
                (schedule) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: YakSokCard(
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.blueSurface,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.medication,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                schedule.medicineName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                schedule.displaySchedule,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              if (schedule.schedule.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: schedule.schedule.map((dose) {
                                    final doseKey = _doseKeyForLabel(dose);
                                    final isDone =
                                        app.doseStatusFor(schedule.id)[doseKey] == true;
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isDone
                                            ? AppColors.accentGreen.withValues(alpha: 0.14)
                                            : AppColors.blueSurface,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        isDone ? '$dose 완료' : dose,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: isDone
                                              ? AppColors.accentGreen
                                              : AppColors.primaryBlue,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ] else if (schedule.displaySchedule.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  schedule.displaySchedule,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 28),
            SectionHeader(
              title: '최근 진료 기록',
              actionText: '전체 보기',
              onAction: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DoctorNotesScreen()),
              ),
            ),
            const SizedBox(height: 12),
            YakSokCard(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DoctorNotesScreen()),
              ),
              child: latestNote == null
                  ? const Text(
                      '아직 진료 기록이 없습니다.',
                      style: TextStyle(color: AppColors.textSecondary),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          latestNote.summaryData.diagnosis.isNotEmpty
                              ? latestNote.summaryData.diagnosis
                              : latestNote.summary,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          latestNote.summary,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DiseasesScreen()),
              ),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '유행 질병 알림',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Color(0xFFE65100),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            trendingDisease == null
                                ? (app.isLoggedIn ? '데이터를 불러오지 못했습니다.' : '프로필 탭에서 로그인 후 이용 가능합니다.')
                                : '${trendingDisease.rank}위 ${trendingDisease.name} · ${trendingDisease.count}건',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Colors.orange,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return '좋은 아침입니다';
    }
    if (hour < 18) {
      return '좋은 오후입니다';
    }
    return '좋은 저녁입니다';
  }

  String _doseKeyForLabel(String label) {
    switch (label) {
      case '아침':
        return 'morning';
      case '점심':
        return 'afternoon';
      case '저녁':
        return 'evening';
      case '취침 전':
        return 'bedtime';
      default:
        return label;
    }
  }
}
