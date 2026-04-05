import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'login_screen.dart';

class SymptomsScreen extends StatefulWidget {
  const SymptomsScreen({super.key});

  @override
  State<SymptomsScreen> createState() => _SymptomsScreenState();
}

class _SymptomsScreenState extends State<SymptomsScreen> {
  final _controller = TextEditingController();
  bool _isAnalyzing = false;
  SymptomAnalysis? _result;

  final List<String> _commonSymptoms = const [
    '두통',
    '발열',
    '기침',
    '콧물',
    '인후통',
    '복통',
    '설사',
    '구역감',
    '피로감',
    '어지러움',
  ];

  final List<String> _selectedSymptoms = [];

  static const Map<String, String> _symptomHints = {
    '두통': '예: 머리가 깨질 듯 아프고, 한쪽만 욱신거리거나 어지럽습니다.',
    '발열': '예: 열이 38도 이상 나고 몸살, 오한이 함께 있습니다.',
    '기침': '예: 기침이 며칠째 계속되고 가래나 숨참이 있습니다.',
    '콧물': '예: 맑은 콧물인지 누런 콧물인지, 코막힘이 있는지 적어주세요.',
    '인후통': '예: 목이 따갑고 삼킬 때 아프며 열도 있습니다.',
    '복통': '예: 배의 어느 쪽이 얼마나 아픈지, 구토나 설사가 있는지 적어주세요.',
    '설사': '예: 하루 몇 번인지, 복통이나 탈수 증상이 있는지 적어주세요.',
    '구역감': '예: 속이 메스껍고 토할 것 같은지, 실제 구토가 있었는지 적어주세요.',
    '피로감': '예: 몸에 힘이 없고, 며칠째 계속되는지 적어주세요.',
    '어지러움': '예: 빙글빙글 도는지, 쓰러질 것 같은지, 귀울림이 있는지 적어주세요.',
  };

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _analyze() async {
    final text = [
      ..._selectedSymptoms,
      if (_controller.text.trim().isNotEmpty) _controller.text.trim(),
    ].join(', ');

    if (text.isEmpty) {
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _result = null;
    });

    try {
      final result = await context.read<AppProvider>().analyzeSymptom(text);
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
        const SnackBar(content: Text('증상 분석 요청에 실패했습니다.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final result = _result;
    final sortedDiseases = result == null
        ? const <PossibleDisease>[]
        : _sortedDiseases(result.possibleDiseases);

    if (!app.isLoggedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('증상 분석')),
        body: LoginRequiredWidget(
          title: '증상 분석은 로그인 후 사용할 수 있어요',
          subtitle: '분석 결과를 기록으로 남기고, 나중에 다시 확인할 수 있습니다.',
          onLogin: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('증상 분석')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.blueSurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.smart_toy_outlined,
                    color: AppColors.primaryBlue,
                    size: 22,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '백엔드 OpenAI 분석 결과를 바탕으로 가능성이 있는 질환을 안내합니다.',
                      style: TextStyle(
                        color: AppColors.primaryBlue,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '자주 있는 증상',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _commonSymptoms.map((symptom) {
                final isSelected = _selectedSymptoms.contains(symptom);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedSymptoms.remove(symptom);
                      } else {
                        _selectedSymptoms.add(symptom);
                      }
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primaryBlue
                          : AppColors.surfaceWhite,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primaryBlue
                            : AppColors.divider,
                      ),
                    ),
                    child: Text(
                      symptom,
                      style: TextStyle(
                        color:
                            isSelected ? Colors.white : AppColors.textPrimary,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            const Text(
              '직접 입력',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _controller,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: _currentHintText(),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: (_selectedSymptoms.isNotEmpty ||
                            _controller.text.trim().isNotEmpty) &&
                        !_isAnalyzing
                    ? _analyze
                    : null,
                icon: _isAnalyzing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.search),
                label: Text(
                  _isAnalyzing ? 'AI 분석 중...' : '증상 분석하기',
                ),
              ),
            ),
            if (result != null) ...[
              const SizedBox(height: 28),
              const Text(
                'AI 분석 결과',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.35),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.local_hospital_outlined,
                          color: Colors.deepOrange,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'AI 결과는 참고용입니다',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.deepOrange,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      result.disclaimer.isNotEmpty
                          ? result.disclaimer
                          : '증상이 계속되거나 심해지면 꼭 병원에 방문해 전문가의 진료를 받으세요.',
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              if (result.isEmergency)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
                  ),
                  child: Text(
                    result.emergencyMessage.isNotEmpty
                        ? result.emergencyMessage
                        : '응급 증상 가능성이 있습니다. 즉시 진료를 권장합니다.',
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                ),
              ...sortedDiseases.asMap().entries.map(
                (entry) {
                  final index = entry.key;
                  final item = entry.value;
                  final isHighRisk = index == 0 || (index == 1 && result.isEmergency);
                  return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: YakSokCard(
                    color: isHighRisk
                        ? const Color(0xFFFFF8F6)
                        : AppColors.surfaceWhite,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: isHighRisk
                                    ? Colors.red.withValues(alpha: 0.12)
                                    : AppColors.blueSurface,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                isHighRisk ? '먼저 확인 필요' : '가능성 ${index + 1}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isHighRisk
                                      ? Colors.red
                                      : AppColors.primaryBlue,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          item.reason,
                          style: const TextStyle(
                            fontSize: 16,
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
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceWhite,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '꼭 기억해 주세요',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'AI 결과만 믿고 지나치지 마시고, 불편한 증상이 있으면 병원에서 꼭 전문가 진료를 받으세요.',
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.6,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _currentHintText() {
    if (_selectedSymptoms.isEmpty) {
      return '예: 가슴이 답답하고 숨이 차며 계단을 오르면 더 심해집니다.';
    }

    if (_selectedSymptoms.length == 1) {
      return _symptomHints[_selectedSymptoms.first] ?? '증상을 자세히 설명해 주세요.';
    }

    final selected = _selectedSymptoms.take(2).join(', ');
    return '$selected 증상이 언제부터 있었는지, 얼마나 심한지 자세히 적어주세요.';
  }

  List<PossibleDisease> _sortedDiseases(List<PossibleDisease> diseases) {
    final sorted = [...diseases];
    sorted.sort((a, b) => _riskScore(b).compareTo(_riskScore(a)));
    return sorted;
  }

  int _riskScore(PossibleDisease disease) {
    final text = '${disease.name} ${disease.reason}'.toLowerCase();
    const highRiskKeywords = [
      '응급',
      '뇌졸중',
      '심근경색',
      '폐렴',
      '협심증',
      '호흡곤란',
      '출혈',
      '장폐색',
      '뇌출혈',
      '심부전',
      '패혈증',
    ];
    for (final keyword in highRiskKeywords) {
      if (text.contains(keyword)) {
        return 100 - highRiskKeywords.indexOf(keyword);
      }
    }
    return 10;
  }
}
