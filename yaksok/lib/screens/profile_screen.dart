import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'login_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final user = app.currentUser;

    // 로그인 안 됐거나 temp_token 으로 추가 정보가 필요한 경우: 로그인/회원가입 유도 화면
    if (!app.isLoggedIn || app.needsRegistration) {
      return Scaffold(
        appBar: AppBar(title: const Text('프로필')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 64, color: AppColors.primaryBlue),
                const SizedBox(height: 12),
                const Text(
                  '로그인이 필요합니다',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  app.needsRegistration
                      ? 'temp_token 상태입니다. 추가 정보를 입력해 회원가입을 마무리하세요.'
                      : '카카오 로그인 또는 token/temp_token으로 연결해 주세요.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                    icon: const Icon(Icons.login),
                    label: Text(app.needsRegistration ? '회원가입 이어서 하기' : '로그인 / 회원가입'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('프로필')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 46,
                    backgroundColor: AppColors.primaryBlue,
                    backgroundImage: user?.profileImage.isNotEmpty == true
                        ? NetworkImage(user!.profileImage)
                        : null,
                    child: user?.profileImage.isNotEmpty == true
                        ? null
                        : Text(
                            user?.name.isNotEmpty == true ? user!.name[0] : 'U',
                            style: const TextStyle(
                              fontSize: 32,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user?.name.isNotEmpty == true ? user!.name : '사용자',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    user?.email ?? '',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  StatusBadge(
                    text: user == null ? '나이 미입력' : '세',
                    color: AppColors.primaryBlue,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.medication,
                    label: '복약 일정',
                    value: '개',
                    color: AppColors.primaryBlue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.health_and_safety,
                    label: '증상 기록',
                    value: '개',
                    color: AppColors.accentGreen,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.description,
                    label: '진료 기록',
                    value: '개',
                    color: AppColors.lightBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            const SectionHeader(title: '기본 정보'),
            const SizedBox(height: 12),
            YakSokCard(
              child: Column(
                children: [
                  _profileRow(
                    icon: Icons.badge_outlined,
                    title: '닉네임',
                    value: user?.nickname.isNotEmpty == true ? user!.nickname : '미등록',
                    color: AppColors.primaryBlue,
                  ),
                  const Divider(height: 20),
                  _profileRow(
                    icon: Icons.wc_outlined,
                    title: '성별',
                    value: _genderLabel(user?.gender ?? ''),
                    color: AppColors.primaryBlue,
                  ),
                  const Divider(height: 20),
                  _profileRow(
                    icon: Icons.home_outlined,
                    title: '주소',
                    value: user?.address.isNotEmpty == true ? user!.address : '미입력',
                    color: AppColors.primaryBlue,
                  ),
                  const Divider(height: 20),
                  _profileRow(
                    icon: Icons.family_restroom,
                    title: '보호자 이메일',
                    value: user?.guardianEmail.isNotEmpty == true
                        ? user!.guardianEmail
                        : '미등록',
                    color: AppColors.primaryBlue,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const SectionHeader(title: '연결 정보'),
            const SizedBox(height: 12),
            YakSokCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '백엔드 주소',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    app.baseUrl,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await context.read<AppProvider>().logout();
                },
                icon: const Icon(Icons.logout, color: Colors.red),
                label: const Text(
                  '로그아웃',
                  style: TextStyle(color: Colors.red, fontSize: 16),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _genderLabel(String gender) {
    switch (gender) {
      case 'male':
        return '남성';
      case 'female':
        return '여성';
      case 'other':
        return '기타';
      default:
        return '미등록';
    }
  }

  Widget _profileRow({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            color: AppColors.textSecondary,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
