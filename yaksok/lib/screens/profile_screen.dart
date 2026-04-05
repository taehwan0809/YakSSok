import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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
    final scheduleCount = app.schedules.length;
    final symptomCount = app.symptomHistory.length;
    final doctorNoteCount = app.doctorNotes.length;

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
                    text: user == null || user.age <= 0 ? '나이 미입력' : '${user.age}세',
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
                    label: '복용 일정',
                    value: '${scheduleCount}개',
                    color: AppColors.primaryBlue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.health_and_safety,
                    label: '증상 기록',
                    value: '${symptomCount}개',
                    color: AppColors.accentGreen,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.description,
                    label: '진료 기록',
                    value: '${doctorNoteCount}개',
                    color: AppColors.lightBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () => _showEditProfileDialog(context, app),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('기본 정보 수정'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const SectionHeader(title: '기본 정보'),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.greenSurface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                '보호자 연락처를 등록하면 진료 기록, 증상 분석 결과, 복용 완료 상태를 보호자와 공유할 수 있습니다.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
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
                  const Divider(height: 20),
                  _profileRow(
                    icon: Icons.phone_outlined,
                    title: '보호자 연락처',
                    value: user?.guardianPhone.isNotEmpty == true
                        ? _formatPhoneNumber(user!.guardianPhone)
                        : '미등록',
                    color: AppColors.primaryBlue,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const SectionHeader(title: '보호자 공유 설정'),
            const SizedBox(height: 12),
            YakSokCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '보호자에게 건강 알림을 보내는 방식',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Builder(builder: (context) {
                    final freq = context.watch<AppProvider>().guardianShareFrequency;
                    final desc = freq == 'manual'
                        ? '홈 화면의 버튼을 눌러야만 보호자에게 전송됩니다.'
                        : freq == 'daily'
                            ? '앱을 열 때 날짜가 바뀌었으면 자동으로 건강 알림을 보냅니다.'
                            : '진료 기록 또는 증상 분석 완료 시 즉시 자동 전송됩니다.';
                    return Text(
                      desc,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                    );
                  }),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: const [
                      _ShareFrequencyChip(value: 'manual', label: '수동 전송'),
                      _ShareFrequencyChip(value: 'daily', label: '하루 1번 자동'),
                      _ShareFrequencyChip(value: 'always', label: '결과 나올 때마다'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () => _showGuardianPhoneDialog(context, app),
                icon: const Icon(Icons.edit_outlined),
                label: Text(
                  user?.guardianPhone.isNotEmpty == true
                      ? '보호자 연락처 수정'
                      : '보호자 연락처 등록',
                ),
              ),
            ),
            if (kDebugMode) ...[
              const SizedBox(height: 24),
              const SectionHeader(title: '개발 연결 정보'),
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
            ],
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

  String _formatPhoneNumber(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length == 11) {
      return '${digits.substring(0, 3)}-${digits.substring(3, 7)}-${digits.substring(7)}';
    }
    if (digits.length == 10) {
      return '${digits.substring(0, 3)}-${digits.substring(3, 6)}-${digits.substring(6)}';
    }
    return value;
  }

  void _showGuardianPhoneDialog(BuildContext context, AppProvider app) {
    final controller = TextEditingController(text: app.currentUser?.guardianPhone ?? '');

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
              '보호자 연락처 등록',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              '진료 기록을 보호자에게 문자로 알릴 때 사용됩니다.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: '보호자 연락처',
                hintText: '예: 010-1234-5678',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () async {
                  try {
                    final message = await context
                        .read<AppProvider>()
                        .updateGuardianPhone(controller.text.trim());
                    if (!ctx.mounted) {
                      return;
                    }
                    Navigator.pop(ctx);
                    if (!context.mounted) {
                      return;
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(message)),
                    );
                  } catch (error) {
                    if (!context.mounted) {
                      return;
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(error.toString())),
                    );
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

  void _showEditProfileDialog(BuildContext context, AppProvider app) {
    final user = app.currentUser;
    if (user == null) {
      return;
    }

    final nameController = TextEditingController(text: user.name);
    final ageController =
        TextEditingController(text: user.age > 0 ? '${user.age}' : '');
    final addressController = TextEditingController(text: user.address);
    final guardianEmailController =
        TextEditingController(text: user.guardianEmail);
    final guardianPhoneController =
        TextEditingController(text: user.guardianPhone);
    var selectedGender = user.gender.isNotEmpty ? user.gender : 'male';

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
          child: SingleChildScrollView(
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
                  '기본 정보 수정',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: '이름',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ageController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '나이',
                    prefixIcon: Icon(Icons.cake_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedGender,
                  decoration: const InputDecoration(
                    labelText: '성별',
                    prefixIcon: Icon(Icons.wc_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'male', child: Text('남성')),
                    DropdownMenuItem(value: 'female', child: Text('여성')),
                    DropdownMenuItem(value: 'other', child: Text('기타')),
                  ],
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setModalState(() {
                      selectedGender = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: addressController,
                  decoration: const InputDecoration(
                    labelText: '주소',
                    prefixIcon: Icon(Icons.home_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      try {
                        final location = await context
                            .read<AppProvider>()
                            .updateCurrentLocation(syncAddress: false);
                        addressController.text = location;
                        if (!ctx.mounted) {
                          return;
                        }
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('현재 위치로 주소를 불러왔습니다.')),
                        );
                      } catch (error) {
                        if (!ctx.mounted) {
                          return;
                        }
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text(error.toString())),
                        );
                      }
                    },
                    icon: const Icon(Icons.my_location_outlined),
                    label: const Text('현재 위치로 주소 가져오기'),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: guardianPhoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: '보호자 연락처',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: guardianEmailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: '보호자 이메일',
                    prefixIcon: Icon(Icons.mail_outline),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () async {
                      final age = int.tryParse(ageController.text.trim());
                      if (age == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('나이는 숫자로 입력해야 합니다.')),
                        );
                        return;
                      }

                      try {
                        await context.read<AppProvider>().updateProfile(
                              name: nameController.text.trim(),
                              age: age,
                              gender: selectedGender,
                              address: addressController.text.trim(),
                              guardianEmail: guardianEmailController.text.trim(),
                              guardianPhone: guardianPhoneController.text.trim(),
                            );
                        if (!ctx.mounted) {
                          return;
                        }
                        Navigator.pop(ctx);
                        if (!context.mounted) {
                          return;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('기본 정보가 수정되었습니다.')),
                        );
                      } catch (error) {
                        if (!context.mounted) {
                          return;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(error.toString())),
                        );
                      }
                    },
                    child: const Text('저장'),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
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

class _ShareFrequencyChip extends StatelessWidget {
  final String value;
  final String label;

  const _ShareFrequencyChip({
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final isSelected = app.guardianShareFrequency == value;

    return ChoiceChip(
      selected: isSelected,
      label: Text(label),
      onSelected: (_) => context
          .read<AppProvider>()
          .updateGuardianShareFrequency(value),
      selectedColor: AppColors.primaryBlue.withValues(alpha: 0.16),
      backgroundColor: AppColors.surfaceWhite,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primaryBlue : AppColors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      side: BorderSide(
        color: isSelected
            ? AppColors.primaryBlue
            : AppColors.divider,
      ),
    );
  }
}
