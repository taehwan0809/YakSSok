import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'login_screen.dart';

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().loadWeather();
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final snapshot = app.weatherSnapshot;
    final weather = snapshot?.weather;
    final air = snapshot?.airQuality;
    final advice = snapshot?.healthAdvice ?? const <String>[];
    final isProfileAddressBased = app.currentUser?.address.isNotEmpty == true;

    if (!app.isLoggedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('날씨 및 건강 정보')),
        body: LoginRequiredWidget(
          title: '날씨와 건강 정보는 로그인 후 볼 수 있어요',
          subtitle: '지역 기반 날씨, 대기질, 건강 조언을 함께 제공합니다.',
          onLogin: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('날씨 및 건강 정보'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<AppProvider>().loadWeather(),
          ),
        ],
      ),
      body: snapshot == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cloud_off_outlined,
                      size: 48,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '날씨 정보를 불러오지 못했습니다.',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      app.errorMessage?.isNotEmpty == true
                          ? app.errorMessage!
                          : '잠시 후 다시 시도해 주세요.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '현재 위치 기준 조회에 실패하면 기본 지역 정보로 다시 시도합니다.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => context.read<AppProvider>().loadWeather(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('다시 불러오기'),
                    ),
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF1565C0),
                          Color(0xFF1E88E5),
                          Color(0xFF42A5F5),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isProfileAddressBased ? '프로필 주소 기준' : '현재 위치 기준',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  app.currentLocationLabel,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  weather?.temperature ?? '정보 없음',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 52,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '${weather?.sky ?? ''}  최고 ${weather?.tempMax ?? '-'} / 최저 ${weather?.tempMin ?? '-'}',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            const Icon(
                              Icons.wb_sunny_rounded,
                              color: Colors.white,
                              size: 80,
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _weatherStat(
                              Icons.water_drop_outlined,
                              '습도',
                              weather?.humidity ?? '-',
                            ),
                            _weatherStat(
                              Icons.air,
                              '풍속',
                              weather?.windSpeed ?? '-',
                            ),
                            _weatherStat(
                              Icons.grain,
                              '강수',
                              weather?.precipitationProbability ?? '-',
                            ),
                            _weatherStat(
                              Icons.cloud,
                              '강수형태',
                              weather?.precipitationType ?? '-',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  YakSokCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.air,
                              color: AppColors.accentGreen,
                              size: 22,
                            ),
                            SizedBox(width: 8),
                            Text(
                              '대기질',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (air == null)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '대기질 정보를 아직 불러오지 못했습니다.',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '현재 저장된 주소를 기준으로 측정소를 다시 찾는 중입니다. 새로고침을 눌러 다시 시도해 주세요.',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          )
                        else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${air.stationName} 측정소 기준',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _aqiItem('미세먼지', air.pm10.value, air.pm10.grade),
                                  ),
                                  Expanded(
                                    child: _aqiItem('초미세먼지', air.pm25.value, air.pm25.grade),
                                  ),
                                  Expanded(
                                    child: _aqiItem('통합지수', air.khai.value, air.khai.grade),
                                  ),
                                ],
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  YakSokCard(
                    color: AppColors.greenSurface,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.favorite_outline,
                              color: AppColors.accentGreen,
                              size: 22,
                            ),
                            SizedBox(width: 8),
                            Text(
                              '오늘의 건강 조언',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.accentGreen,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        if (advice.isEmpty)
                          const Text(
                            '건강 조언이 없습니다.',
                            style: TextStyle(color: AppColors.textSecondary),
                          )
                        else
                          ...advice.map(_healthTip),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _weatherStat(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _aqiItem(String label, String value, String status) {
    final color = _gradeColor(status);
    return Column(
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            status.isEmpty ? '-' : status,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _healthTip(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_outline,
            color: AppColors.accentGreen,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _gradeColor(String grade) {
    switch (grade) {
      case '좋음':
        return AppColors.accentGreen;
      case '보통':
        return Colors.orange;
      case '나쁨':
      case '매우나쁨':
        return Colors.red;
      default:
        return AppColors.textSecondary;
    }
  }
}
