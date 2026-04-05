import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:provider/provider.dart';

import 'providers/app_provider.dart';
import 'screens/main_screen.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  KakaoSdk.init(nativeAppKey: '25122dd7d09cd8f2cf195fbda19adc30');
  try {
    await NotificationService.init();
    await NotificationService.requestPermission();
  } catch (_) {}
  SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const YakSokApp());
}

class YakSokApp extends StatelessWidget {
  const YakSokApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppProvider(),
      child: MaterialApp(
        title: 'YakSok',
        theme: AppTheme.theme,
        debugShowCheckedModeBanner: false,
        home: const _AppEntry(),
      ),
    );
  }
}

class _AppEntry extends StatelessWidget {
  const _AppEntry();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();

    if (app.isInitializing) {
      return const _LoadingScreen();
    }

    // 로그인 여부와 관계없이 메인 화면 먼저 보여주고, 프로필 탭에서 로그인/회원가입을 진행한다.
    return const MainScreen();
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
