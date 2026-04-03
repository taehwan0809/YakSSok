# YakSok 실행 세팅

## 현재 확인된 환경 상태

- `node` / `npm`: 사용 가능
- `flutter`: 현재 PATH에 없음
- `python`: 현재 셸에서 직접 실행 불가

즉, 백엔드는 바로 세팅 가능한 상태이고 Flutter SDK는 먼저 설치가 필요합니다.

## 1. 백엔드 준비

백엔드 디렉터리:

```text
C:\Users\taehwan\YakSSok\YakSok_Backend
```

### 1-1. 환경 변수 파일 만들기

`.env.example`을 복사해서 `.env`를 만듭니다.

```powershell
cd C:\Users\taehwan\YakSSok\YakSok_Backend
Copy-Item .env.example .env
```

필수로 채워야 하는 값:

- `DB_HOST`
- `DB_PORT`
- `DB_USER`
- `DB_PASSWORD`
- `DB_NAME`
- `JWT_SECRET`
- `KAKAO_REST_API_KEY`
- `KAKAO_REDIRECT_URI`
- `KAKAO_LOCAL_API_KEY`
- `OPENAI_API_KEY`
- `PUBLIC_DATA_API_KEY`
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_REGION`
- `AWS_S3_BUCKET`

선택 값:

- `SOLAPI_API_KEY`
- `SOLAPI_API_SECRET`
- `SOLAPI_SENDER`

보호자 SMS 발송 기능을 쓸 계획이 없다면 Solapi 값은 나중에 채워도 됩니다.

### 1-2. 패키지 설치

```powershell
cd C:\Users\taehwan\YakSSok\YakSok_Backend
npm install
```

### 1-3. 백엔드 실행

```powershell
npm run dev
```

정상 실행되면:

```text
http://localhost:3000
```

## 2. Flutter 앱 준비

앱 디렉터리:

```text
C:\Users\taehwan\YakSSok\yaksok
```

### 2-1. 설치가 필요한 것

- Flutter SDK
- Android Studio 또는 Android SDK
- Android 에뮬레이터

### 2-2. Flutter 설치 후 실행

```powershell
cd C:\Users\taehwan\YakSSok\yaksok
flutter pub get
flutter run
```

## 3. 백엔드 주소

- Android 에뮬레이터: `http://10.0.2.2:3000`
- Windows 로컬 실행: `http://127.0.0.1:3000`

로그인 화면에서 수동 연결을 열면 백엔드 주소를 직접 바꿀 수 있습니다.

## 4. 로그인 흐름

1. 백엔드를 실행합니다.
2. 앱의 프로필 탭에서 로그인 화면으로 이동합니다.
3. `카카오로 계속하기`를 누릅니다.
4. 앱 복귀가 안 되면 `토큰 자동 복귀가 안 될 때`를 열고 수동 연결을 사용합니다.
5. `temp_token` 상태면 추가 정보 입력 후 회원가입을 완료합니다.

## 5. 진료 음성 업로드 흐름

1. `진료 기록`으로 이동합니다.
2. `음성 업로드`를 누릅니다.
3. 음성 파일을 선택합니다.
4. 필요하면 방문일을 고릅니다.
5. 업로드 후 Whisper + GPT 요약이 생성됩니다.
6. 보호자 연락처가 등록돼 있으면 상세 화면에서 알림도 보낼 수 있습니다.
