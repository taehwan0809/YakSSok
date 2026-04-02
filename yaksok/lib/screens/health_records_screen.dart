import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class HealthRecordsScreen extends StatelessWidget {
  const HealthRecordsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final records = app.symptomHistory;

    return Scaffold(
      appBar: AppBar(
        title: const Text('건강 기록'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: app.isBusy ? null : app.refreshSymptomHistory,
          ),
        ],
      ),
      body: records.isEmpty
          ? const EmptyStateWidget(
              icon: Icons.health_and_safety_outlined,
              title: '건강 기록이 없습니다',
              subtitle: '증상 분석을 실행하면 기록이 여기에 쌓입니다.',
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceWhite,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.health_and_safety,
                        color: AppColors.accentGreen,
                        size: 32,
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '증상 분석 기록',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            '${records.length}개',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryBlue,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                ...records.map(
                  (record) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: YakSokCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: record.isEmergency
                                      ? const Color(0xFFFFEBEE)
                                      : AppColors.blueSurface,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  record.isEmergency
                                      ? Icons.warning_amber_rounded
                                      : Icons.medical_information,
                                  color: record.isEmergency
                                      ? Colors.red
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
                                      record.symptom,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      record.createdAt == null
                                          ? '분석 시각 없음'
                                          : DateFormat('yyyy.MM.dd HH:mm')
                                              .format(record.createdAt!),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              StatusBadge(
                                text: record.isEmergency ? '응급 의심' : '기록',
                                color: record.isEmergency
                                    ? Colors.red
                                    : AppColors.primaryBlue,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 12),
                          if (record.possibleDiseases.isEmpty)
                            const Text(
                              '가능 질환 정보가 없습니다.',
                              style: TextStyle(color: AppColors.textSecondary),
                            )
                          else
                            ...record.possibleDiseases.map(
                              (item) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      item.reason,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          if (record.isEmergency &&
                              record.emergencyMessage.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              record.emergencyMessage,
                              style: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
