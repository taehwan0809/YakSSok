import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'login_screen.dart';

class MedicineScheduleScreen extends StatelessWidget {
  const MedicineScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final schedules = app.schedules;
    final activeCount = schedules.where((item) => item.isActive).length;

    if (!app.isLoggedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('복용 일정')),
        body: LoginRequiredWidget(
          title: '복용 일정은 로그인 후 관리할 수 있어요',
          subtitle: '진료 기록에서 자동 생성된 약 일정과 직접 등록한 일정을 함께 볼 수 있습니다.',
          onLogin: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('복용 일정'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: app.isBusy ? null : app.refreshSchedules,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddDialog(context),
          ),
        ],
      ),
      body: schedules.isEmpty
          ? const EmptyStateWidget(
              icon: Icons.medication_outlined,
              title: '등록된 일정이 없습니다',
              subtitle: '우측 상단 버튼으로 복용 일정을 추가하세요.',
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.today, color: Colors.white, size: 24),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '활성화된 일정',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            '$activeCount / ${schedules.length}개',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                ...schedules.map(
                  (schedule) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ScheduleCard(schedule: schedule),
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(context),
        backgroundColor: AppColors.primaryBlue,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          '일정 추가',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    final nameController = TextEditingController();
    final scheduleController = TextEditingController();
    final cautionController = TextEditingController();
    int? selectedDays = 7; // 기본값: 7일

    const durationOptions = [
      (null, '무기한'),
      (3, '3일'),
      (5, '5일'),
      (7, '1주 (7일)'),
      (14, '2주 (14일)'),
      (21, '3주 (21일)'),
      (30, '1달 (30일)'),
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '복용 일정 추가',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: '약 이름',
                  hintText: '예: 타이레놀',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: scheduleController,
                decoration: const InputDecoration(
                  labelText: '복용 시간',
                  hintText: '예: 아침, 저녁  /  하루 3회  /  취침 전',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: cautionController,
                decoration: const InputDecoration(
                  labelText: '주의사항 (선택)',
                  hintText: '예: 공복 복용 금지',
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '복용 기간',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: durationOptions.map((opt) {
                  final days = opt.$1;
                  final label = opt.$2;
                  final isSelected = selectedDays == days;
                  return GestureDetector(
                    onTap: () => setModalState(() => selectedDays = days),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primaryBlue : AppColors.blueSurface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? AppColors.primaryBlue : AppColors.divider,
                        ),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () async {
                    if (nameController.text.trim().isEmpty ||
                        scheduleController.text.trim().isEmpty) {
                      return;
                    }
                    DateTime? endDate;
                    if (selectedDays != null) {
                      final today = DateTime.now();
                      endDate = DateTime(today.year, today.month, today.day)
                          .add(Duration(days: selectedDays! - 1));
                    }
                    await context.read<AppProvider>().addSchedule(
                          medicineName: nameController.text.trim(),
                          scheduleText: scheduleController.text.trim(),
                          caution: cautionController.text.trim(),
                          endDate: endDate,
                        );
                    if (context.mounted) {
                      Navigator.pop(ctx);
                    }
                  },
                  child: const Text('저장'),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
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

class _ScheduleCard extends StatelessWidget {
  final MedicineSchedule schedule;

  const _ScheduleCard({required this.schedule});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final doseStatus = app.doseStatusFor(schedule.id);
    final doseKeys = schedule.schedule.map(_doseKeyForLabel).toList();
    final allDone = doseKeys.isNotEmpty &&
        doseKeys.every((doseKey) => doseStatus[doseKey] == true);

    return YakSokCard(
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: schedule.isActive
                      ? AppColors.greenSurface
                      : AppColors.blueSurface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  schedule.isActive
                      ? Icons.check_circle
                      : Icons.pause_circle,
                  color: schedule.isActive
                      ? AppColors.accentGreen
                      : AppColors.primaryBlue,
                  size: 26,
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
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      schedule.displaySchedule,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (schedule.remainingDays != null)
                      Text(
                        schedule.remainingDays == 0
                            ? '오늘 마지막 복용일'
                            : '${schedule.remainingDays}일 남음',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: (schedule.remainingDays ?? 99) <= 2
                              ? Colors.red
                              : AppColors.primaryBlue,
                        ),
                      ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: allDone,
                activeColor: AppColors.accentGreen,
                onChanged: (value) async {
                  for (final doseKey in doseKeys) {
                    final currentValue = doseStatus[doseKey] == true;
                    if (value && !currentValue) {
                      await context.read<AppProvider>().toggleDoseStatus(
                            scheduleId: schedule.id,
                            doseKey: doseKey,
                          );
                    } else if (!value && currentValue) {
                      await context.read<AppProvider>().toggleDoseStatus(
                            scheduleId: schedule.id,
                            doseKey: doseKey,
                          );
                    }
                  }
                },
              ),
            ],
          ),
          if (schedule.schedule.isNotEmpty || schedule.caution.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),
            if (schedule.schedule.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(
                    Icons.task_alt_outlined,
                    size: 18,
                    color: AppColors.accentGreen,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '오늘 복용 완료',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          allDone
                              ? '오늘 일정의 모든 복용 시간을 체크했습니다.'
                              : '아래 시간대를 모두 완료하면 위 토글이 자동으로 켜집니다.',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ...schedule.schedule.map((time) {
                final doseKey = _doseKeyForLabel(time);
                final isDone = doseStatus[doseKey] == true;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: isDone
                        ? AppColors.accentGreen.withValues(alpha: 0.08)
                        : AppColors.blueSurface,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 12),
                            Text(
                              time,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              isDone ? '복용 완료' : '아직 복용 전',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDone
                                    ? AppColors.accentGreen
                                    : AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: isDone,
                        activeColor: AppColors.accentGreen,
                        onChanged: (_) => context.read<AppProvider>().toggleDoseStatus(
                              scheduleId: schedule.id,
                              doseKey: doseKey,
                            ),
                      ),
                      if (app.currentUser?.guardianPhone.isNotEmpty == true)
                        IconButton(
                          tooltip: '보호자에게 공유',
                          onPressed: app.isBusy
                              ? null
                              : () async {
                                  try {
                                    final message = await context
                                        .read<AppProvider>()
                                        .notifyGuardianForDose(
                                          scheduleId: schedule.id,
                                          doseLabel: time,
                                          completed: isDone,
                                        );
                                    if (!context.mounted) {
                                      return;
                                    }
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(message)),
                                    );
                                  } catch (error) {
                                    if (!context.mounted) {
                                      return;
                                    }
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(error.toString())),
                                    );
                                  }
                                },
                          icon: const Icon(Icons.sms_outlined),
                        ),
                    ],
                  ),
                );
              }),
            ],
            if (schedule.caution.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 14,
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      schedule.caution,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () =>
                    context.read<AppProvider>().removeSchedule(schedule.id),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
                child: const Text('삭제'),
              ),
            ],
          ),
        ],
      ),
    );
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
