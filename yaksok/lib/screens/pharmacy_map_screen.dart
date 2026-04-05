import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'login_screen.dart';

class PharmacyMapScreen extends StatefulWidget {
  const PharmacyMapScreen({super.key});

  @override
  State<PharmacyMapScreen> createState() => _PharmacyMapScreenState();
}

class _PharmacyMapScreenState extends State<PharmacyMapScreen> {
  int _selectedIndex = -1;
  final MapController _mapController = MapController();
  final ScrollController _listScrollController = ScrollController();

  // 리스트 아이템 기본 높이 추정값 (패딩 포함)
  static const double _itemCollapsedHeight = 90.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().loadPharmacies();
    });
  }

  @override
  void dispose() {
    _listScrollController.dispose();
    super.dispose();
  }

  void _selectPharmacy(int index, double lat, double lng) {
    setState(() {
      _selectedIndex = index;
    });
    _mapController.move(LatLng(lat, lng), 16);

    // 리스트를 선택된 항목으로 스크롤
    final offset = index * _itemCollapsedHeight;
    if (_listScrollController.hasClients) {
      _listScrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final pharmacies = app.pharmacies;
    final mapCenter = pharmacies.isNotEmpty
        ? LatLng(pharmacies.first.latitude, pharmacies.first.longitude)
        : LatLng(AppProvider.defaultLat, AppProvider.defaultLng);
    final locationLabel = app.currentLocationLabel;
    final isProfileAddressBased = app.currentUser?.address.isNotEmpty == true;

    if (!app.isLoggedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('주변 약국 찾기')),
        body: LoginRequiredWidget(
          title: '주변 약국 찾기는 로그인 후 사용할 수 있어요',
          subtitle: '위치 기반으로 가까운 약국 목록과 연결 링크를 제공합니다.',
          onLogin: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('주변 약국 찾기'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: () async {
              try {
                await context.read<AppProvider>().updateCurrentLocation();
                if (!mounted) {
                  return;
                }
                final app = context.read<AppProvider>();
                _mapController.move(
                  LatLng(app.currentLat, app.currentLng),
                  15,
                );
              } catch (error) {
                if (!mounted) {
                  return;
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(error.toString())),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<AppProvider>().loadPharmacies(),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceWhite,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.my_location_outlined,
                    color: AppColors.primaryBlue,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isProfileAddressBased ? '프로필 주소 기준' : '현재 조회 기준',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          locationLabel,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // 영업 현황 범례
                  Row(
                    children: [
                      _LegendDot(color: Colors.green.shade600),
                      const SizedBox(width: 4),
                      const Text('영업 중', style: TextStyle(fontSize: 11)),
                      const SizedBox(width: 8),
                      _LegendDot(color: Colors.red.shade600),
                      const SizedBox(width: 4),
                      const Text('영업 종료', style: TextStyle(fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            flex: 6,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: mapCenter,
                    initialZoom: 15,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.yaksok.yaksok',
                    ),
                    MarkerLayer(
                      markers: pharmacies.asMap().entries.map((entry) {
                        final index = entry.key;
                        final pharmacy = entry.value;
                        final isSelected = _selectedIndex == index;
                        final markerColor = isSelected
                            ? AppColors.primaryBlue
                            : (pharmacy.isOpen
                                ? Colors.green.shade600
                                : Colors.red.shade600);
                        return Marker(
                          point: LatLng(
                            pharmacy.latitude,
                            pharmacy.longitude,
                          ),
                          width: 36,
                          height: 36,
                          child: GestureDetector(
                            onTap: () => _selectPharmacy(
                              index,
                              pharmacy.latitude,
                              pharmacy.longitude,
                            ),
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: markerColor,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.25),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                                border: isSelected
                                    ? Border.all(color: Colors.white, width: 2)
                                    : null,
                              ),
                              child: const Icon(
                                Icons.local_pharmacy,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: pharmacies.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _listScrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: pharmacies.length,
                    itemBuilder: (context, index) {
                      final pharmacy = pharmacies[index];
                      final isSelected = _selectedIndex == index;

                      return GestureDetector(
                        onTap: () => _selectPharmacy(
                          index,
                          pharmacy.latitude,
                          pharmacy.longitude,
                        ),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceWhite,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primaryBlue
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppColors.primaryBlue
                                            : AppColors.blueSurface,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        Icons.local_pharmacy,
                                        color: isSelected
                                            ? Colors.white
                                            : AppColors.primaryBlue,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            pharmacy.name,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            pharmacy.address,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          pharmacy.distanceLabel,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primaryBlue,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: pharmacy.isOpen
                                                ? Colors.green.shade50
                                                : Colors.red.shade50,
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            pharmacy.isOpen ? '영업 중' : '영업 종료',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: pharmacy.isOpen
                                                  ? Colors.green.shade700
                                                  : Colors.red.shade700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                if (isSelected) ...[
                                  const SizedBox(height: 10),
                                  const Divider(height: 1),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.phone,
                                        size: 14,
                                        color: AppColors.textSecondary,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        pharmacy.phone,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.primaryBlue,
                                        ),
                                      ),
                                      const Spacer(),
                                      if (pharmacy.todayHours != null)
                                        Text(
                                          '오늘 ${pharmacy.todayHours}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.textSecondary,
                                          ),
                                        )
                                      else
                                        Text(
                                          '* 영업 시간은 추정값입니다',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: AppColors.textSecondary
                                                .withValues(alpha: 0.7),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: pharmacy.phone == '번호 없음'
                                              ? null
                                              : () => _launch(
                                                    'tel:${pharmacy.phone}',
                                                  ),
                                          icon: const Icon(Icons.call, size: 16),
                                          label: const Text('전화'),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: pharmacy.kakaoUrl.isEmpty
                                              ? null
                                              : () => _launch(pharmacy.kakaoUrl),
                                          icon: const Icon(
                                            Icons.directions,
                                            size: 16,
                                          ),
                                          label: const Text('상세 보기'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _launch(String value) async {
    final uri = Uri.parse(value);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  const _LegendDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
