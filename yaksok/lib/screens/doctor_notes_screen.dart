import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class DoctorNotesScreen extends StatelessWidget {
  const DoctorNotesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final notes = app.doctorNotes;

    return Scaffold(
      appBar: AppBar(
        title: const Text('진료 기록'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: app.isBusy ? null : app.refreshDoctorNotes,
          ),
        ],
      ),
      body: notes.isEmpty
          ? const EmptyStateWidget(
              icon: Icons.description_outlined,
              title: '진료 기록이 없습니다',
              subtitle: '백엔드에서 음성 업로드 후 AI 요약을 생성하면 여기 표시됩니다.',
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: notes.length,
              itemBuilder: (context, index) {
                final note = notes[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: YakSokCard(
                    onTap: () => _showNoteDetail(context, note),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.greenSurface,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.local_hospital,
                                color: AppColors.accentGreen,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    note.summaryData.diagnosis.isNotEmpty
                                        ? note.summaryData.diagnosis
                                        : '진료 기록',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    note.visitDate == null
                                        ? '방문일 미등록'
                                        : DateFormat('yyyy.MM.dd')
                                            .format(note.visitDate!),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios,
                              size: 14,
                              color: AppColors.textSecondary,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 12),
                        Text(
                          note.summary,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textPrimary,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: app.isBusy ? null : () => _showUploadDialog(context),
        backgroundColor: Colors.red,
        icon: const Icon(Icons.mic, color: Colors.white),
        label: const Text(
          '음성 업로드',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  Future<void> _showNoteDetail(BuildContext context, DoctorNote note) async {
    final detailed = await context.read<AppProvider>().loadDoctorNoteDetail(note.id);
    if (!context.mounted) {
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (_, controller) => SingleChildScrollView(
          controller: controller,
          padding: const EdgeInsets.all(24),
          child: Column(
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
              Text(
                detailed.summaryData.diagnosis.isNotEmpty
                    ? detailed.summaryData.diagnosis
                    : '진료 요약',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                detailed.visitDate == null
                    ? '방문일 미등록'
                    : DateFormat('yyyy.MM.dd').format(detailed.visitDate!),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              _DetailSection(
                title: '전체 요약',
                child: Text(
                  detailed.summary,
                  style: const TextStyle(height: 1.6),
                ),
              ),
              if (detailed.summaryData.medications.isNotEmpty) ...[
                const SizedBox(height: 16),
                _DetailSection(
                  title: '처방/복용 안내',
                  child: Column(
                    children: detailed.summaryData.medications
                        .map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.medication_outlined,
                                  size: 18,
                                  color: AppColors.primaryBlue,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${item.name}\n${item.schedule}\n${item.caution}',
                                    style: const TextStyle(height: 1.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
              if (detailed.summaryData.precautions.isNotEmpty) ...[
                const SizedBox(height: 16),
                _DetailSection(
                  title: '주의사항',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: detailed.summaryData.precautions
                        .map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text('• $item'),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
              if (detailed.summaryData.nextVisit.isNotEmpty) ...[
                const SizedBox(height: 16),
                _DetailSection(
                  title: '다음 방문',
                  child: Text(detailed.summaryData.nextVisit),
                ),
              ],
              if (detailed.originalText.isNotEmpty) ...[
                const SizedBox(height: 16),
                _DetailSection(
                  title: '원문 텍스트',
                  child: Text(
                    detailed.originalText,
                    style: const TextStyle(height: 1.6),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showUploadDialog(BuildContext context) {
    DateTime? selectedDate;
    PlatformFile? pickedFile;

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
                '진료 음성 업로드',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                'mp3, m4a, wav, webm 등의 파일을 선택하면 백엔드에서 Whisper와 GPT로 분석합니다.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final result = await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: const [
                        'mp3',
                        'm4a',
                        'mp4',
                        'wav',
                        'webm',
                        'ogg',
                        'flac',
                      ],
                      withData: true,
                    );
                    if (result == null || result.files.isEmpty) {
                      return;
                    }
                    setModalState(() {
                      pickedFile = result.files.single;
                    });
                  },
                  icon: const Icon(Icons.upload_file),
                  label: Text(
                    pickedFile == null ? '음성 파일 선택' : pickedFile!.name,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: ctx,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (date == null) {
                      return;
                    }
                    setModalState(() {
                      selectedDate = date;
                    });
                  },
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text(
                    selectedDate == null
                        ? '방문일 선택(선택사항)'
                        : DateFormat('yyyy-MM-dd').format(selectedDate!),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: pickedFile == null
                      ? null
                      : () async {
                          final bytes = pickedFile!.bytes;
                          if (bytes == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('파일 데이터를 읽지 못했습니다. 다시 선택해 주세요.'),
                              ),
                            );
                            return;
                          }

                          try {
                            final note =
                                await context.read<AppProvider>().uploadDoctorNoteAudio(
                                      bytes: bytes,
                                      fileName: pickedFile!.name,
                                      visitDate: selectedDate == null
                                          ? null
                                          : DateFormat('yyyy-MM-dd')
                                              .format(selectedDate!),
                                    );
                            if (!ctx.mounted) {
                              return;
                            }
                            Navigator.pop(ctx);
                            if (!context.mounted) {
                              return;
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '분석 완료: ${note.summaryData.diagnosis.isNotEmpty ? note.summaryData.diagnosis : note.summary}',
                                ),
                              ),
                            );
                          } catch (_) {
                            if (!context.mounted) {
                              return;
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('음성 업로드 또는 분석에 실패했습니다.'),
                              ),
                            );
                          }
                        },
                  child: const Text('업로드 및 분석'),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _DetailSection({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
