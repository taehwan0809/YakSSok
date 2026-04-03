import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
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

    _tokenController.text = token;
    await _connect();
  }

  Future<void> _openKakaoAuth() async {
    final app = context.read<AppProvider>();

    try {
      final authUrl = await app.fetchKakaoAuthUrl(_baseUrlController.text);
      if (authUrl.isEmpty) {
        throw const ApiException('카카오 로그인 URL을 불러오지 못했습니다.');
      }

      final launched = await launchUrl(
        Uri.parse(authUrl),
        mode: LaunchMode.inAppBrowserView,
      );

      if (!launched && mounted) {
        _showMessage('브라우저를 열 수 없습니다.');
        return;
      }

      if (mounted) {
        _showMessage('카카오 로그인 후 앱으로 자동 복귀합니다.');
      }
    } on ApiException catch (error) {
      if (mounted) {
        _showMessage(error.message);
      }
    } catch (_) {
      if (mounted) {
        _showMessage('백엔드 서버에 연결할 수 없습니다.');
      }
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
      );
    } on ApiException catch (error) {
      if (mounted) {
        _showMessage(error.message);
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
              SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: app.isBusy ? null : _openKakaoAuth,
                  icon: const Icon(Icons.login),
                  label: const Text('카카오로 계속하기'),
                  style: ElevatedButton.styleFrom(
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '에뮬레이터에서는 카카오톡 앱 대신 웹 로그인으로 진행됩니다.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  setState(() {
                    _showManualFallback = !_showManualFallback;
                  });
                },
                child: Text(
                  _showManualFallback ? '수동 복구 닫기' : '토큰 자동 복귀가 안 될 때',
                ),
              ),
              if (_showManualFallback) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _baseUrlController,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: '백엔드 주소',
                    prefixIcon: Icon(Icons.link),
                  ),
                ),
                const SizedBox(height: 12),
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
