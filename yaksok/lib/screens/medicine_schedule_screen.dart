import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class MedicineScheduleScreen extends StatelessWidget {
  const MedicineScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final schedules = app.schedules;
    final activeCount = schedules.where((item) => item.isActive).length;

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
                    child: YakSokCard(
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
                                  ],
                                ),
                              ),
                              Switch(
                                value: schedule.isActive,
                                activeColor: AppColors.accentGreen,
                                onChanged: (_) => context
                                    .read<AppProvider>()
                                    .toggleScheduleActive(schedule),
                              ),
                            ],
                          ),
                          if (schedule.schedule.isNotEmpty || schedule.caution.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            const Divider(height: 1),
                            const SizedBox(height: 10),
                            if (schedule.schedule.isNotEmpty)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.access_time,
                                    size: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: schedule.schedule
                                          .map(
                                            (time) => Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 3,
                                              ),
                                              decoration: BoxDecoration(
                                                color: AppColors.blueSurface,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                time,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: AppColors.primaryBlue,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  ),
                                ],
                              ),
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
                                onPressed: () => context
                                    .read<AppProvider>()
                                    .removeSchedule(schedule.id),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red,
                                ),
                                child: const Text('삭제'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
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
                labelText: '복용 시간 또는 규칙',
                hintText: '예: 아침, 저녁 또는 하루 2회 식후 30분',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: cautionController,
              decoration: const InputDecoration(
                labelText: '주의사항',
                hintText: '예: 공복 복용 금지',
              ),
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
                  await context.read<AppProvider>().addSchedule(
                        medicineName: nameController.text.trim(),
                        scheduleText: scheduleController.text.trim(),
                        caution: cautionController.text.trim(),
                      );
                  if (ctx.mounted) {
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
    );
  }
}
