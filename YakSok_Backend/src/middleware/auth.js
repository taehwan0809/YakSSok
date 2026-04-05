const jwt = require('jsonwebtoken');
const { pool } = require('../config/database');

// 일반 JWT 인증 미들웨어
async function authenticate(req, res, next) {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ success: false, message: '인증 토큰이 없습니다.' });
  }

  const token = authHeader.split(' ')[1];

  let decoded;
  try {
    decoded = jwt.verify(token, process.env.JWT_SECRET);
  } catch (err) {
    return res.status(401).json({ success: false, message: '유효하지 않은 토큰입니다.' });
  }

  try {
    const [rows] = await pool.query(
      'SELECT id, kakao_id, is_registered FROM users WHERE id = ?',
      [decoded.id]
    );
    if (rows.length === 0) {
      return res.status(401).json({ success: false, message: '유저를 찾을 수 없습니다.' });
    }

    req.user = {
      ...decoded,
      id: rows[0].id,
      kakao_id: rows[0].kakao_id,
      is_registered: !!rows[0].is_registered,
    };
    next();
  } catch (dbErr) {
    console.error('[DB 인증 오류]', dbErr.message);
    return res.status(503).json({
      success: false,
      message: '서버 데이터베이스에 일시적인 오류가 발생했습니다. 잠시 후 다시 시도해주세요.',
    });
  }
}

// 회원가입 완료 여부 확인 미들웨어
function requireRegistered(req, res, next) {
  if (!req.user.is_registered) {
    return res.status(403).json({
      success: false,
      message: '추가 정보 입력이 필요합니다. /auth/register 를 먼저 호출하세요.',
    });
  }
  next();
}

module.exports = { authenticate, requireRegistered };
