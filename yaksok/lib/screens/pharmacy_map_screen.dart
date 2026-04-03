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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().loadPharmacies();
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final pharmacies = app.pharmacies;
    final mapCenter = pharmacies.isNotEmpty
        ? LatLng(pharmacies.first.latitude, pharmacies.first.longitude)
        : LatLng(AppProvider.defaultLat, AppProvider.defaultLng);
    final locationLabel = app.currentLocationLabel;

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
                        const Text(
                          '현재 조회 기준',
                          style: TextStyle(
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
                        return Marker(
                          point: LatLng(
                            pharmacy.latitude,
                            pharmacy.longitude,
                          ),
                          width: 56,
                          height: 56,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedIndex = index;
                              });
                              _mapController.move(
                                LatLng(pharmacy.latitude, pharmacy.longitude),
                                16,
                              );
                            },
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primaryBlue
                                    : Colors.red,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.16),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.local_pharmacy,
                                color: Colors.white,
                                size: 20,
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
                    padding: const EdgeInsets.all(16),
                    itemCount: pharmacies.length,
                    itemBuilder: (context, index) {
                      final pharmacy = pharmacies[index];
                      final isSelected = _selectedIndex == index;

                      return GestureDetector(
                        onTap: () {
                          setState(() => _selectedIndex = index);
                          _mapController.move(
                            LatLng(pharmacy.latitude, pharmacy.longitude),
                            16,
                          );
                        },
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
                                    Text(
                                      pharmacy.distanceLabel,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primaryBlue,
                                      ),
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
