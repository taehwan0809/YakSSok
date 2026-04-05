import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/app_provider.dart';
import '../services/backend_api.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _baseUrlController = TextEditingController(text: AppProvider.defaultBaseUrl);
  final _tokenController = TextEditingController();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _addressController = TextEditingController();
  final _guardianEmailController = TextEditingController();
  final _guardianPhoneController = TextEditingController();

  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSub;
  String _selectedGender = 'male';
  bool _showManualFallback = false;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppProvider>();
    if (app.baseUrl.isNotEmpty) {
      _baseUrlController.text = app.baseUrl;
    }
    _tokenController.text = app.authToken;
    _initAppLinks();
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _tokenController.dispose();
    _nameController.dispose();
    _ageController.dispose();
    _addressController.dispose();
    _guardianEmailController.dispose();
    _guardianPhoneController.dispose();
    _linkSub?.cancel();
    super.dispose();
  }

  Future<void> _initAppLinks() async {
    _appLinks = AppLinks();

    _linkSub = _appLinks.uriLinkStream.listen(
      (uri) => unawaited(_handleIncomingUri(uri)),
      onError: (_) {},
    );

    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        unawaited(_handleIncomingUri(initialUri));
      }
    } catch (_) {}
  }

  Future<void> _handleIncomingUri(Uri uri) async {
    if (!mounted) {
      return;
    }
    if (uri.scheme != 'yaksok' || uri.host != 'auth') {
      return;
    }

    final token =
        uri.queryParameters['token'] ?? uri.queryParameters['temp_token'];
    if (token == null || token.isEmpty) {
      return;
    }

    // 카카오에서 받은 닉네임/이메일로 폼 미리 채우기
    final nickname = uri.queryParameters['nickname'];
    final email = uri.queryParameters['email'];
    if (nickname != null && nickname.isNotEmpty && _nameController.text.isEmpty) {
      _nameController.text = nickname;
    }
    if (email != null && email.isNotEmpty && _guardianEmailController.text.isEmpty) {
      // 이메일은 보호자 이메일이 아니라 참고용이므로 주소 힌트로만 활용
    }

    _tokenController.text = token;
    await _connect();
  }

  Future<void> _openKakaoAuth() async {
    final app = context.read<AppProvider>();

    try {
      OAuthToken kakaoToken;

      // 카카오톡 앱이 설치되어 있으면 앱으로, 없으면 웹으로
      if (await isKakaoTalkInstalled()) {
        kakaoToken = await UserApi.instance.loginWithKakaoTalk();
      } else {
        kakaoToken = await UserApi.instance.loginWithKakaoAccount();
      }

      // 카카오 액세스 토큰을 백엔드로 전달해 JWT 발급
      final result = await app.loginWithKakaoSdk(
        baseUrl: _baseUrlController.text,
        kakaoAccessToken: kakaoToken.accessToken,
      );

      if (!mounted) return;

      // 닉네임으로 이름 필드 미리 채우기
      final nickname = result['nickname'] as String?;
      if (nickname != null && nickname.isNotEmpty && _nameController.text.isEmpty) {
        _nameController.text = nickname;
      }

      final token = result['token'] as String?;
      final tempToken = result['temp_token'] as String?;
      _tokenController.text = token ?? tempToken ?? '';

      await _connect();
    } on KakaoAuthException catch (e) {
      if (mounted) _showMessage('카카오 로그인 실패: ${e.message}');
    } on KakaoClientException catch (e) {
      if (mounted) _showMessage('카카오 SDK 오류: ${e.message}');
    } on ApiException catch (error) {
      if (mounted) _showMessage(error.message);
    } catch (e) {
      if (mounted) _showMessage('로그인 중 오류가 발생했습니다.');
    }
  }

  Future<void> _connect() async {
    final app = context.read<AppProvider>();
    final baseUrl = _baseUrlController.text.trim();
    final token = _tokenController.text.trim();

    if (baseUrl.isEmpty || token.isEmpty) {
      _showMessage('카카오 로그인 토큰을 받지 못했습니다.');
      return;
    }

    try {
      await app.connect(baseUrl: baseUrl, token: token);
      if (!mounted) {
        return;
      }

      if (app.needsRegistration) {
        _showMessage('추가 정보를 입력해 회원가입을 마무리하세요.');
        return;
      }

      if (app.isLoggedIn) {
        _showMessage('로그인되었습니다.');
        Navigator.of(context).pop();
      }
    } on ApiException catch (error) {
      if (mounted) {
        _showMessage(error.message);
      }
    } catch (_) {
      if (mounted) {
        _showMessage('백엔드 연결 중 오류가 발생했습니다.');
      }
    }
  }

  Future<void> _register() async {
    final age = int.tryParse(_ageController.text.trim());
    if (age == null) {
      _showMessage('나이는 숫자로 입력해야 합니다.');
      return;
    }

    final app = context.read<AppProvider>();
    try {
      await app.completeRegistration(
        name: _nameController.text.trim(),
        age: age,
        gender: _selectedGender,
        address: _addressController.text.trim(),
        guardianEmail: _guardianEmailController.text.trim(),
        guardianPhone: _guardianPhoneController.text.trim(),
      );
      if (!mounted) {
        return;
      }
      _showMessage('회원가입이 완료되었습니다.');
      Navigator.of(context).pop();
    } on ApiException catch (error) {
      if (mounted) {
        _showMessage(error.message);
      }
    } catch (_) {
      if (mounted) {
        _showMessage('회원가입 중 오류가 발생했습니다.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              Center(
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primaryBlue, AppColors.lightBlue],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(
                    Icons.chat_bubble_rounded,
                    color: Colors.white,
                    size: 42,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '카카오 로그인',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryBlue,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '이 앱은 카카오 OAuth만 사용합니다. 로그인 후 앱으로 자동 복귀합니다.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              GestureDetector(
                onTap: app.isBusy ? null : _openKakaoAuth,
                child: Opacity(
                  opacity: app.isBusy ? 0.5 : 1.0,
                  child: Image.asset(
                    'public/kakao_login_medium_wide.png',
                    fit: BoxFit.fitWidth,
                  ),
                ),
              ),
              if (kDebugMode) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _showManualFallback = !_showManualFallback;
                    });
                  },
                  child: Text(
                    _showManualFallback ? '수동 토큰 연결 닫기' : '수동 토큰으로 연결',
                  ),
                ),
                if (_showManualFallback) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _tokenController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: '토큰 붙여넣기',
                      prefixIcon: Icon(Icons.vpn_key_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: app.isBusy ? null : _connect,
                    child: const Text('수동 연결'),
                  ),
                ],
              ],
              if (app.needsRegistration) ...[
                const SizedBox(height: 28),
                const Text(
                  '추가 정보 입력',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '첫 로그인 상태입니다. 정보를 입력하면 회원가입이 완료됩니다.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.greenSurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.family_restroom_outlined,
                        color: AppColors.accentGreen,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '보호자 연락처나 이메일을 함께 등록하면 진료 기록, 증상 분석 결과, 복용 완료 상태를 보호자와 공유할 수 있습니다. 원하지 않으면 나중에 프로필에서 등록해도 됩니다.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textPrimary,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '보호자 공유 설정',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '지금 등록하면 보호자가 사용자의 건강 상태를 함께 확인할 수 있습니다.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: '이름',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _ageController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '나이',
                    prefixIcon: Icon(Icons.cake_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedGender,
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
                    setState(() {
                      _selectedGender = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: '주소',
                    prefixIcon: Icon(Icons.home_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _guardianPhoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: '보호자 연락처(선택)',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _guardianEmailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: '보호자 이메일(선택)',
                    prefixIcon: Icon(Icons.mail_outline),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: app.isBusy ? null : _register,
                    child: const Text('회원가입 완료'),
                  ),
                ),
              ],
              if (app.errorMessage != null && app.errorMessage!.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  app.errorMessage!,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
