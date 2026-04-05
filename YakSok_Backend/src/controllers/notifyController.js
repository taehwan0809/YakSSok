const { pool }    = require('../config/database');
const { sendSMS } = require('../utils/aligoSMS');

/**
 * 진료 기록 요약을 LMS 메시지 문자열로 변환
 */
function buildMessage(userName, note, schedules) {
  const s = note.summary || {};
  const lines = [];

  lines.push(`[약쏙] ${userName || '사용자'} 님의 진료 알림`);
  lines.push('');

  if (note.visit_date) {
    lines.push(`진료일: ${note.visit_date}`);
  }

  if (s.diagnosis) {
    lines.push(`진단: ${s.diagnosis}`);
  }

  if (schedules.length > 0) {
    lines.push('');
    lines.push('▶ 처방 약 복용 일정');
    for (const sch of schedules) {
      const times = sch.schedule_times.length > 0
        ? sch.schedule_times.join(', ')
        : (sch.schedule_text || '일정 없음');
      const caution = sch.caution ? ` (주의: ${sch.caution})` : '';
      lines.push(`- ${sch.medicine_name}: ${times}${caution}`);
    }
  } else if (s.medications && s.medications.length > 0) {
    lines.push('');
    lines.push('▶ 처방 약');
    for (const med of s.medications) {
      const caution = med.caution ? ` (주의: ${med.caution})` : '';
      lines.push(`- ${med.name}: ${med.schedule || ''}${caution}`);
    }
  }

  if (s.precautions && s.precautions.length > 0) {
    lines.push('');
    lines.push('▶ 주의사항');
    for (const p of s.precautions) {
      lines.push(`- ${p}`);
    }
  }

  if (s.next_visit) {
    lines.push('');
    lines.push(`다음 방문: ${s.next_visit}`);
  }

  if (s.summary) {
    lines.push('');
    lines.push(`한줄 요약: ${s.summary}`);
  }

  lines.push('');
  lines.push('- 약쏙 앱');

  return lines.join('\n');
}

function buildSymptomMessage(userName, symptomRecord) {
  const lines = [];
  const diseases = Array.isArray(symptomRecord.possible_diseases)
    ? symptomRecord.possible_diseases
    : [];

  lines.push(`[약쏙] ${userName || '사용자'} 님의 증상 분석 알림`);
  lines.push('');
  lines.push(`입력 증상: ${symptomRecord.symptom_text}`);

  if (diseases.length > 0) {
    lines.push('');
    lines.push('▶ AI가 먼저 확인이 필요하다고 본 가능성');
    diseases.slice(0, 3).forEach((disease, index) => {
      lines.push(`- ${index + 1}. ${disease.name}: ${disease.reason}`);
    });
  }

  if (symptomRecord.is_emergency) {
    lines.push('');
    lines.push('응급 가능성이 있어 빠른 진료가 필요하다고 안내되었습니다.');
  }

  lines.push('');
  lines.push('AI 분석은 참고용이며, 증상이 있으면 병원에서 전문가 상담이 꼭 필요합니다.');
  lines.push('- 약쏙 앱');
  return lines.join('\n');
}

function parseJsonArray(value) {
  if (Array.isArray(value)) {
    return value;
  }
  if (value == null || value == 'null' || value == '') {
    return [];
  }

  try {
    const parsed = typeof value === 'string' ? JSON.parse(value) : value;
    return Array.isArray(parsed) ? parsed : [];
  } catch (_) {
    return [];
  }
}

function parseJsonObject(value) {
  if (value == null || value == 'null' || value == '') {
    return {};
  }
  if (typeof value === 'object' && !Array.isArray(value)) {
    return value;
  }

  try {
    const parsed = typeof value === 'string' ? JSON.parse(value) : value;
    return parsed && typeof parsed === 'object' && !Array.isArray(parsed)
      ? parsed
      : {};
  } catch (_) {
    return {};
  }
}

function buildDoseMessage(userName, payload) {
  const lines = [];
  lines.push(`[약쏙] ${userName || '사용자'} 님의 복용 완료 알림`);
  lines.push('');
  lines.push(`약 이름: ${payload.medicine_name}`);
  lines.push(`복용 시간: ${payload.dose_label}`);
  lines.push(`상태: ${payload.completed ? '복용 완료' : '복용 전으로 변경'}`);
  if (payload.schedule_text) {
    lines.push(`기록된 일정: ${payload.schedule_text}`);
  }
  if (payload.caution) {
    lines.push(`주의사항: ${payload.caution}`);
  }
  lines.push('');
  lines.push('- 약쏙 앱');
  return lines.join('\n');
}

/**
 * POST /doctor-note/:id/notify
 * 보호자에게 진료 기록 + 약 복용 일정을 SMS로 발송
 */
async function notifyGuardian(req, res) {
  const { id } = req.params;

  try {
    // 유저 정보 조회 (보호자 연락처 확인)
    const [userRows] = await pool.query(
      'SELECT name, guardian_phone FROM users WHERE id = ?',
      [req.user.id]
    );
    const user = userRows[0];

    if (!user.guardian_phone) {
      return res.status(400).json({
        success: false,
        message: '등록된 보호자 연락처가 없습니다. /auth/guardian 에서 먼저 등록해주세요.',
      });
    }

    // 진료 기록 조회
    const [noteRows] = await pool.query(
      'SELECT id, summary, visit_date FROM doctor_notes WHERE id = ? AND user_id = ?',
      [id, req.user.id]
    );
    if (noteRows.length === 0) {
      return res.status(404).json({ success: false, message: '진료 기록을 찾을 수 없습니다.' });
    }

    const note = noteRows[0];
    note.summary = parseJsonObject(note.summary);

    // 해당 진료 기록에 연결된 약 복용 일정 조회
    const [schedRows] = await pool.query(
      `SELECT medicine_name, morning, afternoon, evening, bedtime, schedule_text, caution
       FROM medicine_schedules
       WHERE note_id = ? AND user_id = ? AND is_active = 1`,
      [id, req.user.id]
    );

    const schedules = schedRows.map((row) => {
      const times = [];
      if (row.morning)   times.push('아침');
      if (row.afternoon) times.push('점심');
      if (row.evening)   times.push('저녁');
      if (row.bedtime)   times.push('취침 전');
      return {
        medicine_name:  row.medicine_name,
        schedule_times: times,
        schedule_text:  row.schedule_text,
        caution:        row.caution,
      };
    });

    // 메시지 생성 및 발송
    const msg = buildMessage(user.name, note, schedules);
    const result = await sendSMS({
      receiver: user.guardian_phone,
      msg,
      title: `[약쏙] ${user.name || '사용자'} 님 진료 알림`,
    });

    return res.json({
      success: true,
      message: `보호자(${user.guardian_phone})에게 알림을 발송했습니다.`,
      data: {
        messageId:  result.messageId,
        statusCode: result.statusCode,
      },
    });
  } catch (err) {
    console.error('[notifyGuardian 오류]', err.message);
    return res.status(500).json({
      success: false,
      message: '알림 발송 중 오류가 발생했습니다.',
      error: err.message,
    });
  }
}

async function notifyGuardianForSymptom(req, res) {
  const { id } = req.params;

  try {
    const [userRows] = await pool.query(
      'SELECT name, guardian_phone FROM users WHERE id = ?',
      [req.user.id]
    );
    const user = userRows[0];

    if (!user?.guardian_phone) {
      return res.status(400).json({
        success: false,
        message: '등록된 보호자 연락처가 없습니다. 먼저 프로필에서 등록해주세요.',
      });
    }

    const [rows] = await pool.query(
      `SELECT id, symptom_text, possible_diseases, is_emergency
       FROM symptoms
       WHERE id = ? AND user_id = ?`,
      [id, req.user.id]
    );

    if (rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: '증상 기록을 찾을 수 없습니다.',
      });
    }

    const symptomRecord = rows[0];
    symptomRecord.possible_diseases = parseJsonArray(
      symptomRecord.possible_diseases
    );

    const msg = buildSymptomMessage(user.name, symptomRecord);
    const result = await sendSMS({
      receiver: user.guardian_phone,
      msg,
      title: `[약쏙] ${user.name || '사용자'} 님 증상 분석 알림`,
    });

    return res.json({
      success: true,
      message: `보호자(${user.guardian_phone})에게 증상 분석 알림을 발송했습니다.`,
      data: {
        mid: result.mid,
        msg_count: result.msg_count,
        sent_count: result.sent_cnt,
      },
    });
  } catch (err) {
    console.error('[notifyGuardianForSymptom 오류]', err.message);
    return res.status(500).json({
      success: false,
      message: '증상 알림 발송 중 오류가 발생했습니다.',
      error: err.message,
    });
  }
}

async function notifyGuardianForDose(req, res) {
  const { id } = req.params;
  const { dose_label, completed } = req.body;

  if (!dose_label || typeof dose_label !== 'string') {
    return res.status(400).json({
      success: false,
      message: 'dose_label 값이 필요합니다.',
    });
  }

  try {
    const [userRows] = await pool.query(
      'SELECT name, guardian_phone FROM users WHERE id = ?',
      [req.user.id]
    );
    const user = userRows[0];

    if (!user?.guardian_phone) {
      return res.status(400).json({
        success: false,
        message: '등록된 보호자 연락처가 없습니다. 먼저 프로필에서 등록해주세요.',
      });
    }

    const [rows] = await pool.query(
      `SELECT medicine_name, schedule_text, caution
       FROM medicine_schedules
       WHERE id = ? AND user_id = ?`,
      [id, req.user.id]
    );

    if (rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: '복용 일정을 찾을 수 없습니다.',
      });
    }

    const payload = {
      medicine_name: rows[0].medicine_name,
      schedule_text: rows[0].schedule_text,
      caution: rows[0].caution,
      dose_label,
      completed: completed === true,
    };

    const msg = buildDoseMessage(user.name, payload);
    const result = await sendSMS({
      receiver: user.guardian_phone,
      msg,
      title: `[약쏙] ${user.name || '사용자'} 님 복용 상태 알림`,
    });

    return res.json({
      success: true,
      message: `보호자(${user.guardian_phone})에게 복용 상태 알림을 발송했습니다.`,
      data: {
        mid: result.mid,
        msg_count: result.msg_count,
        sent_count: result.sent_cnt,
      },
    });
  } catch (err) {
    console.error('[notifyGuardianForDose 오류]', err.message);
    return res.status(500).json({
      success: false,
      message: '복용 상태 알림 발송 중 오류가 발생했습니다.',
      error: err.message,
    });
  }
}

/**
 * PUT /auth/guardian
 * 보호자 연락처 등록/수정
 * body: { guardian_phone }
 */
async function updateGuardian(req, res) {
  const { guardian_phone } = req.body;

  if (!guardian_phone) {
    return res.status(400).json({ success: false, message: 'guardian_phone 은 필수입니다.' });
  }

  // 숫자와 하이픈만 허용, 10~11자리
  const cleaned = guardian_phone.replace(/-/g, '');
  if (!/^\d{10,11}$/.test(cleaned)) {
    return res.status(400).json({
      success: false,
      message: '올바른 전화번호 형식이 아닙니다. 예: 010-1234-5678',
    });
  }

  try {
    await pool.query(
      'UPDATE users SET guardian_phone = ? WHERE id = ?',
      [cleaned, req.user.id]
    );
    return res.json({
      success: true,
      message: '보호자 연락처가 등록되었습니다.',
      data: { guardian_phone: cleaned },
    });
  } catch (err) {
    console.error('[updateGuardian 오류]', err.message);
    return res.status(500).json({ success: false, message: '서버 오류가 발생했습니다.' });
  }
}

/**
 * POST /notify/health-summary
 * 최근 진료 기록 + 증상 분석 + 복용 일정을 통합해서 보호자에게 SMS 발송
 */
async function notifyHealthSummary(req, res) {
  try {
    const [userRows] = await pool.query(
      'SELECT name, guardian_phone FROM users WHERE id = ?',
      [req.user.id]
    );
    const user = userRows[0];

    if (!user?.guardian_phone) {
      return res.status(400).json({
        success: false,
        message: '등록된 보호자 연락처가 없습니다. 먼저 프로필에서 등록해주세요.',
      });
    }

    // 최근 진료 기록
    const [noteRows] = await pool.query(
      'SELECT id, summary, visit_date FROM doctor_notes WHERE user_id = ? ORDER BY created_at DESC LIMIT 1',
      [req.user.id]
    );
    const latestNote = noteRows[0] || null;
    if (latestNote) {
      latestNote.summary = parseJsonObject(latestNote.summary);
    }

    // 최근 증상 분석
    const [symptomRows] = await pool.query(
      'SELECT symptom_text, possible_diseases, is_emergency FROM symptoms WHERE user_id = ? ORDER BY created_at DESC LIMIT 1',
      [req.user.id]
    );
    const latestSymptom = symptomRows[0] || null;
    if (latestSymptom) {
      latestSymptom.possible_diseases = parseJsonArray(latestSymptom.possible_diseases);
    }

    // 활성 복용 일정
    const [schedRows] = await pool.query(
      'SELECT medicine_name, morning, afternoon, evening, bedtime, schedule_text, caution FROM medicine_schedules WHERE user_id = ? AND is_active = 1 ORDER BY created_at DESC LIMIT 10',
      [req.user.id]
    );

    if (!latestNote && !latestSymptom && schedRows.length === 0) {
      return res.status(400).json({
        success: false,
        message: '전송할 건강 기록이 없습니다.',
      });
    }

    const today = new Date(Date.now() + 9 * 60 * 60 * 1000);
    const dateStr = `${today.getUTCFullYear()}년 ${today.getUTCMonth() + 1}월 ${today.getUTCDate()}일`;

    const lines = [];
    lines.push(`━━━━━━━━━━━━━━━━━━━━`);
    lines.push(`💊 약쏙 건강 알림`);
    lines.push(`${user.name || '사용자'} 어르신 · ${dateStr}`);
    lines.push(`━━━━━━━━━━━━━━━━━━━━`);

    // 진료 기록 섹션
    if (latestNote) {
      lines.push('');
      lines.push('🏥 [최근 진료 기록]');
      if (latestNote.visit_date) lines.push(`진료일: ${latestNote.visit_date}`);
      if (latestNote.summary?.diagnosis) lines.push(`진단 내용: ${latestNote.summary.diagnosis}`);
      if (latestNote.summary?.summary) lines.push(`한줄 요약: ${latestNote.summary.summary}`);
      if (latestNote.summary?.precautions?.length > 0) {
        lines.push('주의사항:');
        latestNote.summary.precautions.slice(0, 3).forEach((p) => lines.push(`  · ${p}`));
      }
      if (latestNote.summary?.next_visit) lines.push(`다음 진료: ${latestNote.summary.next_visit}`);
    }

    // 복용 일정 섹션
    if (schedRows.length > 0) {
      lines.push('');
      lines.push('💊 [복용 중인 약]');
      for (const row of schedRows) {
        const times = [];
        if (row.morning)   times.push('아침');
        if (row.afternoon) times.push('점심');
        if (row.evening)   times.push('저녁');
        if (row.bedtime)   times.push('취침 전');
        const timeStr = times.length > 0 ? times.join('·') : (row.schedule_text || '시간 미정');
        lines.push(`  ✓ ${row.medicine_name}`);
        lines.push(`    복용 시간: ${timeStr}`);
        if (row.caution) lines.push(`    주의: ${row.caution}`);
      }
    }

    // 증상 분석 섹션
    if (latestSymptom) {
      lines.push('');
      lines.push('🔍 [최근 증상 기록]');
      lines.push(`증상: ${latestSymptom.symptom_text}`);
      if (latestSymptom.is_emergency) {
        lines.push('⚠️ 응급 가능성이 있어 빠른 진료가 필요합니다!');
      }
      const diseases = latestSymptom.possible_diseases.slice(0, 2);
      if (diseases.length > 0) {
        lines.push('의심 질환:');
        diseases.forEach((d) => lines.push(`  · ${d.name}: ${d.reason}`));
      }
    }

    lines.push('');
    lines.push(`━━━━━━━━━━━━━━━━━━━━`);
    lines.push('약쏙 앱으로 더 자세한 내용을 확인하세요.');

    const msg = lines.join('\n');
    const result = await sendSMS({
      receiver: user.guardian_phone,
      msg,
      title: `[약쏙] ${user.name || '사용자'} 님 건강 알림`,
    });

    return res.json({
      success: true,
      message: `보호자(${user.guardian_phone})에게 건강 알림을 발송했습니다.`,
      data: { messageId: result.messageId },
    });
  } catch (err) {
    console.error('[notifyHealthSummary 오류]', err.message);
    return res.status(500).json({
      success: false,
      message: '건강 알림 발송 중 오류가 발생했습니다.',
      error: err.message,
    });
  }
}

module.exports = {
  notifyGuardian,
  notifyGuardianForSymptom,
  notifyGuardianForDose,
  notifyHealthSummary,
  updateGuardian,
};
