# YakSok Backend Setup

## 1. Clone

```powershell
cd C:\Users\hongk\Desktop\yakyak\yaksok
git clone https://github.com/CSH0805/YakSok_Backend.git backend
cd backend
```

## 2. Install

```powershell
npm install
```

## 3. Environment Variables

Create `backend/.env` with the following keys:

```env
PORT=3000

DB_HOST=
DB_PORT=
DB_USER=
DB_PASSWORD=
DB_NAME=

JWT_SECRET=
JWT_EXPIRES_IN=7d
TEMP_TOKEN_EXPIRES_IN=1d

KAKAO_REST_API_KEY=
KAKAO_REDIRECT_URI=
KAKAO_LOCAL_API_KEY=

OPENAI_API_KEY=
PUBLIC_DATA_API_KEY=

AWS_REGION=
AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
AWS_S3_BUCKET=
```

## 4. Run

```powershell
npm run dev
```

## 5. Flutter App

Android emulator:

```text
http://10.0.2.2:3000
```

Windows desktop:

```text
http://127.0.0.1:3000
```

## 6. Login Flow

1. Run the backend.
2. Open the Flutter app login screen.
3. Enter the backend URL.
4. Tap `카카오 로그인 열기`.
5. Complete Kakao login in the browser.
6. Copy the returned `token` or `temp_token`.
7. Paste it into the app and tap `백엔드 연결`.
8. If you got `temp_token`, complete the registration form in the app.

## 7. Doctor Note Upload Flow

1. Open `진료 기록`.
2. Tap `음성 업로드`.
3. Pick an audio file.
4. Optionally set the visit date.
5. Tap `업로드 및 분석`.

The app calls:

1. `GET /doctor-note/presigned-url`
2. `PUT <presigned S3 URL>`
3. `POST /doctor-note/process`
