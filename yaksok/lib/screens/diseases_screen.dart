import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/app_provider.dart';
import '../services/backend_api.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'login_screen.dart';

class DiseasesScreen extends StatefulWidget {
  const DiseasesScreen({super.key});

  @override
  State<DiseasesScreen> createState() => _DiseasesScreenState();
}

class _DiseasesScreenState extends State<DiseasesScreen> {
  String _selectedRegion = AppProvider.defaultRegion;

  static const List<String> _regions = [
    '서울',
    '부산',
    '대구',
    '인천',
    '광주',
    '대전',
    '울산',
    '경기',
    '강원',
    '충북',
    '충남',
    '전북',
    '전남',
    '경북',
    '경남',
    '제주',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().loadDiseases(region: _selectedRegion);
    });
  }

  Future<void> _showPreventionSheet(BuildContext context, DiseaseTrend item) async {
    DiseasePreventionInfo? info;
    bool loading = true;
    bool fetchStarted = false;
    String? errorMsg;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          if (!fetchStarted) {
            fetchStarted = true;
            context.read<AppProvider>()
                .fetchDiseasePreventionInfo(item.name)
                .then((result) {
              if (ctx.mounted) setSheet(() { info = result; loading = false; });
            }).catchError((e) {
              if (ctx.mounted) setSheet(() { errorMsg = e.toString(); loading = false; });
            });
          }
          return DraggableScrollableSheet(
            initialChildSize: 0.7,
            maxChildSize: 0.95,
            minChildSize: 0.4,
            expand: false,
            builder: (_, sc) => SingleChildScrollView(
              controller: sc,
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.name,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ),
                      StatusBadge(
                        text: item.grade.isEmpty ? '분류 없음' : item.grade,
                        color: AppColors.primaryBlue,
                      ),
                    ],
                  ),
                  Text(
                    '${item.region} · ${item.year}년 ${item.count}건',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  if (loading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Column(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 12),
                            Text('AI가 예방 정보를 분석 중입니다...', style: TextStyle(color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                    )
                  else if (errorMsg != null)
                    Text('정보를 불러오지 못했습니다.', style: const TextStyle(color: Colors.red))
                  else if (info != null) ...[
                    if (info!.overview.isNotEmpty) ...[
                      _PreventionSection(title: '질병 설명', items: [info!.overview], icon: Icons.info_outline),
                      const SizedBox(height: 16),
                    ],
                    if (info!.symptoms.isNotEmpty) ...[
                      _PreventionSection(title: '주요 증상', items: info!.symptoms, icon: Icons.sick_outlined),
                      const SizedBox(height: 16),
                    ],
                    if (info!.prevention.isNotEmpty) ...[
                      _PreventionSection(title: '예방법', items: info!.prevention, icon: Icons.shield_outlined, iconColor: AppColors.accentGreen),
                      const SizedBox(height: 16),
                    ],
                    if (info!.warningSigns.isNotEmpty)
                      _PreventionSection(title: '즉시 병원에 가야 하는 경우', items: info!.warningSigns, icon: Icons.warning_amber_outlined, iconColor: Colors.orange),
                  ],
                  const SizedBox(height: 8),
                  const Text(
                    '* AI 생성 정보는 참고용이며 의료적 진단이 아닙니다.',
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final snapshot = app.diseaseSnapshot;
    final items = snapshot?.topDiseases ?? const [];

    if (!app.isLoggedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('유행 질병 현황')),
        body: LoginRequiredWidget(
          title: '유행 질병 정보는 로그인 후 볼 수 있어요',
          subtitle: '지역별 감염병 현황과 주의 안내를 확인할 수 있습니다.',
          onLogin: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('유행 질병 현황'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context
                .read<AppProvider>()
                .loadDiseases(region: _selectedRegion),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedRegion,
              decoration: const InputDecoration(
                labelText: '조회 지역',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
              items: _regions
                  .map(
                    (region) => DropdownMenuItem(
                      value: region,
                      child: Text(region),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _selectedRegion = value;
                });
                context.read<AppProvider>().loadDiseases(region: value);
              },
            ),
            const SizedBox(height: 16),
            if (snapshot != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primaryBlue, AppColors.darkBlue],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${snapshot.source} ${snapshot.year}년 데이터',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '분석 대상 질병 ${snapshot.totalDiseases}개',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snapshot.notice,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            if (snapshot == null)
              const Center(child: CircularProgressIndicator())
            else if (items.isEmpty)
              const EmptyStateWidget(
                icon: Icons.coronavirus_outlined,
                title: '질병 데이터가 없습니다',
                subtitle: '다른 지역으로 다시 조회해 보세요.',
              )
            else
              ...items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: YakSokCard(
                    onTap: () => _showPreventionSheet(context, item),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: AppColors.blueSurface,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  '${item.rank}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryBlue,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '${item.region} · ${item.count}건',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            StatusBadge(
                              text: item.grade.isEmpty ? '분류 없음' : item.grade,
                              color: AppColors.primaryBlue,
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.arrow_forward_ios,
                              size: 12,
                              color: AppColors.textSecondary,
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
      ),
    );
  }
}

class _PreventionSection extends StatelessWidget {
  final String title;
  final List<String> items;
  final IconData icon;
  final Color iconColor;

  const _PreventionSection({
    required this.title,
    required this.items,
    required this.icon,
    this.iconColor = AppColors.primaryBlue,
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
          Row(
            children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: iconColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.circle, size: 6, color: iconColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(item, style: const TextStyle(fontSize: 14, height: 1.4)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
