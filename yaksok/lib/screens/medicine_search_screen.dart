import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class MedicineSearchScreen extends StatefulWidget {
  const MedicineSearchScreen({super.key});

  @override
  State<MedicineSearchScreen> createState() => _MedicineSearchScreenState();
}

class _MedicineSearchScreenState extends State<MedicineSearchScreen> {
  final _controller = TextEditingController();
  bool _isSearching = false;
  MedicineSearchRecord? _result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().refreshMedicineHistory();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return;
    }

    setState(() {
      _isSearching = true;
      _result = null;
    });

    try {
      final result = await context.read<AppProvider>().recommendMedicine(trimmed);
      if (!mounted) {
        return;
      }
      setState(() {
        _result = result;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('약 추천 요청에 실패했습니다.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final history = context.watch<AppProvider>().medicineHistory;

    return Scaffold(
      appBar: AppBar(title: const Text('약 추천')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: '증상이나 복용 목적을 입력하세요',
                      prefixIcon: Icon(Icons.medication_outlined),
                    ),
                    onSubmitted: _search,
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 52,
                  width: 52,
                  child: ElevatedButton(
                    onPressed: _isSearching ? null : () => _search(_controller.text),
                    style: ElevatedButton.styleFrom(padding: EdgeInsets.zero),
                    child: _isSearching
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.search),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_result == null && !_isSearching) ...[
              const Text(
                '최근 추천 기록',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              if (history.isEmpty)
                const YakSokCard(
                  child: Text(
                    '아직 추천 기록이 없습니다.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              else
                ...history.take(5).map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: YakSokCard(
                          onTap: () {
                            setState(() {
                              _result = item;
                              _controller.text = item.input;
                            });
                          },
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
                                  Icons.history,
                                  color: AppColors.primaryBlue,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.input,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      item.recommendations.isEmpty
                                          ? '추천 결과 없음'
                                          : item.recommendations
                                              .map((value) => value.name)
                                              .join(', '),
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
                        ),
                      ),
                    ),
            ],
            if (_result != null && !_isSearching) ...[
              Text(
                '"${_result!.input}" 추천 결과',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              if (_result!.disclaimer.isNotEmpty)
                Text(
                  _result!.disclaimer,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              const SizedBox(height: 16),
              ..._result!.recommendations.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: YakSokCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _InfoBlock(title: '효능', content: item.efficacy),
                        const SizedBox(height: 10),
                        _InfoBlock(title: '복용 방법', content: item.howToTake),
                        const SizedBox(height: 10),
                        _InfoBlock(title: '주의사항', content: item.caution),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  final String title;
  final String content;

  const _InfoBlock({
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.primaryBlue,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          content.isEmpty ? '정보 없음' : content,
          style: const TextStyle(
            color: AppColors.textPrimary,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
