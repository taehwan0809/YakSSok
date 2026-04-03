# YakSok Flutter App

약쏙 Flutter 클라이언트입니다. 노인 사용자를 위한 건강 관리, 증상 분석, 진료 기록 요약, 복약 일정 관리 기능을 제공합니다.

## 주요 기능

- 카카오 OAuth 기반 로그인 및 추가 정보 등록
- 증상 분석 기록 조회
- 일반 의약품 추천 및 검색 기록 조회
- 진료 음성 업로드 후 AI 요약 확인
- 진료 요약 기반 복약 일정 자동 생성
- 날씨, 대기질, 유행 질병, 주변 약국 조회
- 보호자 연락처 등록 및 진료 알림 발송

## 실행 전 준비

이 앱은 Flutter SDK가 필요합니다. 현재 이 작업 환경에서는 `flutter` 명령이 PATH에 잡혀 있지 않았습니다.

필요한 준비물:

- Flutter SDK
- Android Studio 또는 Android SDK + 에뮬레이터
- 백엔드 서버 실행 환경

## 실행 방법

1. 백엔드를 먼저 실행합니다.
2. 이 디렉터리에서 의존성을 설치합니다.

```powershell
flutter pub get
```

3. Android 에뮬레이터라면 기본 백엔드 주소는 `http://10.0.2.2:3000` 입니다.
4. 앱을 실행합니다.

```powershell
flutter run
```

## 테스트

```powershell
flutter test
```

## 참고

- 상세 백엔드 준비는 [`BACKEND_SETUP.md`](/C:/Users/taehwan/YakSSok/yaksok/BACKEND_SETUP.md)를 참고하세요.
