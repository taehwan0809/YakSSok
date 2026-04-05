const axios = require('axios');
const jwt = require('jsonwebtoken');
const { pool } = require('../config/database');
require('dotenv').config();

const KAKAO_REST_API_KEY = process.env.KAKAO_REST_API_KEY;
const KAKAO_REDIRECT_URI = process.env.KAKAO_REDIRECT_URI;

// ─────────────────────────────────────────
// 내부 헬퍼 함수
// ─────────────────────────────────────────

function generateToken(payload, expiresIn) {
  return jwt.sign(payload, process.env.JWT_SECRET, { expiresIn });
}

async function getKakaoAccessToken(code) {
  const response = await axios.post(
    'https://kauth.kakao.com/oauth/token',
    new URLSearchParams({
      grant_type: 'authorization_code',
      client_id: KAKAO_REST_API_KEY,
      redirect_uri: KAKAO_REDIRECT_URI,
      code,
    }),
    { headers: { 'Content-Type': 'application/x-www-form-urlencoded' } }
  );
  return response.data.access_token;
}

async function getKakaoUserInfo(accessToken) {
  const response = await axios.get('https://kapi.kakao.com/v2/user/me', {
    headers: { Authorization: `Bearer ${accessToken}` },
  });
  const data = response.data;
  return {
    kakao_id: String(data.id),
    email: data.kakao_account?.email || null,
    nickname: data.kakao_account?.profile?.nickname || null,
    profile_image: data.kakao_account?.profile?.profile_image_url || null,
  };
}

// ─────────────────────────────────────────
// 컨트롤러
// ─────────────────────────────────────────

/**
 * GET /auth/kakao
 * 카카오 로그인 페이지 URL 반환
 */
function getKakaoAuthUrl(req, res) {
  const authUrl =
    `https://kauth.kakao.com/oauth/authorize` +
    `?client_id=${KAKAO_REST_API_KEY}` +
    `&redirect_uri=${encodeURIComponent(KAKAO_REDIRECT_URI)}` +
    `&response_type=code`;

  return res.json({
    success: true,
    message: '아래 URL을 브라우저에서 열어 카카오 로그인을 진행하세요.',
    auth_url: authUrl,
  });
}

/**
 * GET /auth/kakao/callback?code=...
 * 카카오 인가 코드 처리 → 신규/기존 회원 분기
 */
async function kakaoCallback(req, res) {
  const { code } = req.query;
  if (!code) {
    return res.status(400).json({ success: false, message: '인가 코드(code)가 없습니다.' });
  }

  try {
    // 1. 카카오 액세스 토큰 발급
    const kakaoAccessToken = await getKakaoAccessToken(code);

    // 2. 카카오 유저 정보 조회
    const kakaoUser = await getKakaoUserInfo(kakaoAccessToken);

    // 3. DB에서 해당 카카오 ID 조회
    const [rows] = await pool.query('SELECT * FROM users WHERE kakao_id = ?', [kakaoUser.kakao_id]);

    if (rows.length > 0) {
      const user = rows[0];

      if (user.is_registered) {
        // ── 기존 회원 (추가 정보 입력 완료) ──
        const token = generateToken(
          { id: user.id, kakao_id: user.kakao_id, is_registered: true },
          process.env.JWT_EXPIRES_IN
        );
        return res.redirect(`yaksok://auth/kakao?token=${encodeURIComponent(token)}`);
      } else {
        // ── 카카오 로그인은 했지만 추가 정보 미입력 ──
        const tempToken = generateToken(
          { id: user.id, kakao_id: user.kakao_id, is_registered: false },
          process.env.TEMP_TOKEN_EXPIRES_IN
        );
        const existingParams = new URLSearchParams({ temp_token: tempToken });
        if (user.nickname) existingParams.set('nickname', user.nickname);
        if (user.email) existingParams.set('email', user.email);
        return res.redirect(`yaksok://auth/kakao?${existingParams.toString()}`);
      }
    } else {
      // ── 신규 회원: DB에 카카오 정보 저장 ──
      const [result] = await pool.query(
        `INSERT INTO users (kakao_id, email, nickname, profile_image, is_registered)
         VALUES (?, ?, ?, ?, 0)`,
        [kakaoUser.kakao_id, kakaoUser.email, kakaoUser.nickname, kakaoUser.profile_image]
      );
      const newUserId = result.insertId;

      const tempToken = generateToken(
        { id: newUserId, kakao_id: kakaoUser.kakao_id, is_registered: false },
        process.env.TEMP_TOKEN_EXPIRES_IN
      );

      const newParams = new URLSearchParams({ temp_token: tempToken });
      if (kakaoUser.nickname) newParams.set('nickname', kakaoUser.nickname);
      if (kakaoUser.email) newParams.set('email', kakaoUser.email);
      return res.redirect(`yaksok://auth/kakao?${newParams.toString()}`);
    }
  } catch (err) {
    console.error('[kakaoCallback 오류]', err.response?.data || err.message);
    return res.status(500).json({
      success: false,
      message: '카카오 인증 처리 중 오류가 발생했습니다.',
      error: err.response?.data || err.message,
    });
  }
}

/**
 * POST /auth/register
 * 추가 정보 입력 (이름, 나이, 성별, 주소)
 * Header: Authorization: Bearer <temp_token>
 */
async function register(req, res) {
  const { name, age, gender, address, guardian_email, guardian_phone } = req.body;

  // 유효성 검사
  const errors = [];
  if (!name || typeof name !== 'string' || name.trim() === '') errors.push('이름(name)은 필수입니다.');
  if (!age || isNaN(age) || age < 1 || age > 130) errors.push('나이(age)는 1~130 사이의 숫자여야 합니다.');
  if (!gender || !['male', 'female', 'other'].includes(gender))
    errors.push('성별(gender)은 male / female / other 중 하나여야 합니다.');
  if (!address || typeof address !== 'string' || address.trim() === '')
    errors.push('주소(address)는 필수입니다.');
  if (guardian_email && typeof guardian_email !== 'string') {
    errors.push('보호자 이메일(guardian_email) 형식이 올바르지 않습니다.');
  }
  if (guardian_phone) {
    const cleanedPhone = String(guardian_phone).replace(/-/g, '');
    if (!/^\d{10,11}$/.test(cleanedPhone)) {
      errors.push('보호자 연락처(guardian_phone)는 10~11자리 전화번호여야 합니다.');
    }
  }

  if (errors.length > 0) {
    return res.status(400).json({ success: false, message: '입력값 오류', errors });
  }

  try {
    const userId = req.user.id;

    const cleanedGuardianPhone = guardian_phone
      ? String(guardian_phone).replace(/-/g, '')
      : null;

    // DB 업데이트
    await pool.query(
      `UPDATE users
       SET name = ?, age = ?, gender = ?, address = ?, guardian_email = ?, guardian_phone = ?, is_registered = 1
       WHERE id = ?`,
      [
        name.trim(),
        Number(age),
        gender,
        address.trim(),
        guardian_email?.trim() || null,
        cleanedGuardianPhone,
        userId,
      ]
    );

    // 업데이트된 유저 조회
    const [rows] = await pool.query('SELECT * FROM users WHERE id = ?', [userId]);
    const user = rows[0];

    // 정식 JWT 발급
    const token = generateToken(
      { id: user.id, kakao_id: user.kakao_id, is_registered: true },
      process.env.JWT_EXPIRES_IN
    );

    return res.json({
      success: true,
      status: 'registered',
      message: '회원가입이 완료되었습니다.',
      token,
      user: {
        id: user.id,
        name: user.name,
        nickname: user.nickname,
        email: user.email,
        age: user.age,
        gender: user.gender,
        address: user.address,
        guardian_email: user.guardian_email,
        guardian_phone: user.guardian_phone,
        profile_image: user.profile_image,
      },
    });
  } catch (err) {
    console.error('[register 오류]', err.message);
    return res.status(500).json({ success: false, message: '서버 오류가 발생했습니다.' });
  }
}

/**
 * GET /auth/me
 * 내 정보 조회
 * Header: Authorization: Bearer <token>
 */
async function getMe(req, res) {
  try {
    const [rows] = await pool.query('SELECT * FROM users WHERE id = ?', [req.user.id]);
    if (rows.length === 0) {
      return res.status(404).json({ success: false, message: '유저를 찾을 수 없습니다.' });
    }
    const user = rows[0];
    return res.json({
      success: true,
      user: {
        id: user.id,
        name: user.name,
        nickname: user.nickname,
        email: user.email,
        age: user.age,
        gender: user.gender,
        address: user.address,
        profile_image: user.profile_image,
        guardian_email: user.guardian_email,
        guardian_phone: user.guardian_phone,
        is_registered: !!user.is_registered,
        created_at: user.created_at,
      },
    });
  } catch (err) {
    console.error('[getMe 오류]', err.message);
    return res.status(500).json({ success: false, message: '서버 오류가 발생했습니다.' });
  }
}

async function updateProfile(req, res) {
  const { name, age, gender, address, guardian_email, guardian_phone } = req.body;

  const errors = [];
  if (name != null && (typeof name !== 'string' || name.trim() === '')) {
    errors.push('이름(name)은 비워둘 수 없습니다.');
  }
  if (age != null && (isNaN(age) || Number(age) < 1 || Number(age) > 130)) {
    errors.push('나이(age)는 1~130 사이의 숫자여야 합니다.');
  }
  if (gender != null && !['male', 'female', 'other'].includes(gender)) {
    errors.push('성별(gender)은 male / female / other 중 하나여야 합니다.');
  }
  if (address != null && (typeof address !== 'string' || address.trim() === '')) {
    errors.push('주소(address)는 비워둘 수 없습니다.');
  }
  if (guardian_email != null && guardian_email !== '' && typeof guardian_email !== 'string') {
    errors.push('보호자 이메일(guardian_email) 형식이 올바르지 않습니다.');
  }

  let cleanedGuardianPhone = null;
  if (guardian_phone != null) {
    if (guardian_phone === '') {
      cleanedGuardianPhone = '';
    } else {
      cleanedGuardianPhone = String(guardian_phone).replace(/-/g, '');
      if (!/^\d{10,11}$/.test(cleanedGuardianPhone)) {
        errors.push('보호자 연락처(guardian_phone)는 10~11자리 전화번호여야 합니다.');
      }
    }
  }

  if (errors.length > 0) {
    return res.status(400).json({ success: false, message: '입력값 오류', errors });
  }

  try {
    await pool.query(
      `UPDATE users
       SET name = COALESCE(?, name),
           age = COALESCE(?, age),
           gender = COALESCE(?, gender),
           address = COALESCE(?, address),
           guardian_email = CASE WHEN ? IS NULL THEN guardian_email ELSE ? END,
           guardian_phone = CASE WHEN ? IS NULL THEN guardian_phone ELSE ? END
       WHERE id = ?`,
      [
        name?.trim() || null,
        age != null ? Number(age) : null,
        gender || null,
        address?.trim() || null,
        guardian_email ?? null,
        guardian_email?.trim() || null,
        guardian_phone ?? null,
        cleanedGuardianPhone,
        req.user.id,
      ]
    );

    const [rows] = await pool.query('SELECT * FROM users WHERE id = ?', [req.user.id]);
    const user = rows[0];

    return res.json({
      success: true,
      message: '기본 정보가 수정되었습니다.',
      user: {
        id: user.id,
        name: user.name,
        nickname: user.nickname,
        email: user.email,
        age: user.age,
        gender: user.gender,
        address: user.address,
        guardian_email: user.guardian_email,
        guardian_phone: user.guardian_phone,
        profile_image: user.profile_image,
        is_registered: !!user.is_registered,
        created_at: user.created_at,
      },
    });
  } catch (err) {
    console.error('[updateProfile 오류]', err.message);
    return res.status(500).json({ success: false, message: '서버 오류가 발생했습니다.' });
  }
}

/**
 * POST /auth/logout
 * 로그아웃 (클라이언트 토큰 폐기 안내)
 */
function logout(req, res) {
  return res.json({
    success: true,
    message: '로그아웃 되었습니다. 클라이언트에서 토큰을 삭제해주세요.',
  });
}

/**
 * POST /auth/kakao/sdk-login
 * 카카오 Flutter SDK 에서 발급한 액세스 토큰으로 로그인
 * Body: { access_token: "..." }
 */
async function kakaoSdkLogin(req, res) {
  const { access_token } = req.body;
  if (!access_token) {
    return res.status(400).json({ success: false, message: 'access_token이 필요합니다.' });
  }

  try {
    const kakaoUser = await getKakaoUserInfo(access_token);
    const [rows] = await pool.query('SELECT * FROM users WHERE kakao_id = ?', [kakaoUser.kakao_id]);

    if (rows.length > 0) {
      const user = rows[0];

      if (user.is_registered) {
        const token = generateToken(
          { id: user.id, kakao_id: user.kakao_id, is_registered: true },
          process.env.JWT_EXPIRES_IN
        );
        return res.json({ success: true, status: 'login', token, nickname: user.nickname });
      } else {
        const tempToken = generateToken(
          { id: user.id, kakao_id: user.kakao_id, is_registered: false },
          process.env.TEMP_TOKEN_EXPIRES_IN
        );
        return res.json({ success: true, status: 'needs_registration', temp_token: tempToken, nickname: user.nickname });
      }
    } else {
      const [result] = await pool.query(
        `INSERT INTO users (kakao_id, email, nickname, profile_image, is_registered) VALUES (?, ?, ?, ?, 0)`,
        [kakaoUser.kakao_id, kakaoUser.email, kakaoUser.nickname, kakaoUser.profile_image]
      );
      const tempToken = generateToken(
        { id: result.insertId, kakao_id: kakaoUser.kakao_id, is_registered: false },
        process.env.TEMP_TOKEN_EXPIRES_IN
      );
      return res.status(201).json({ success: true, status: 'needs_registration', temp_token: tempToken, nickname: kakaoUser.nickname });
    }
  } catch (err) {
    console.error('[kakaoSdkLogin 오류]', err.response?.data || err.message);
    return res.status(500).json({ success: false, message: '카카오 인증 처리 중 오류가 발생했습니다.' });
  }
}

module.exports = { getKakaoAuthUrl, kakaoCallback, kakaoSdkLogin, register, getMe, updateProfile, logout };
