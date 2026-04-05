const OpenAI                              = require('openai');
const axios                               = require('axios');
const FormData                            = require('form-data');
const { pool }                            = require('../config/database');
const { getPresignedUploadUrl, downloadFromS3, deleteFromS3 } = require('../utils/s3Uploader');
const { parseScheduleText }               = require('./scheduleController');
require('dotenv').config();

const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });

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

// 매직 바이트로 실제 오디오 포맷 감지
function detectAudioFormat(buffer) {
  const b = buffer;
  // WebM / MKV: 1A 45 DF A3
  if (b[0] === 0x1a && b[1] === 0x45 && b[2] === 0xdf && b[3] === 0xa3) return 'webm';
  // MP4 / M4A: ftyp (bytes 4~7)
  if (b[4] === 0x66 && b[5] === 0x74 && b[6] === 0x79 && b[7] === 0x70) return 'm4a';
  // MP3: ID3 태그 또는 FF FB/F3/F2
  if (b[0] === 0x49 && b[1] === 0x44 && b[2] === 0x33) return 'mp3';
  if (b[0] === 0xff && (b[1] === 0xfb || b[1] === 0xf3 || b[1] === 0xf2)) return 'mp3';
  // WAV: RIFF
  if (b[0] === 0x52 && b[1] === 0x49 && b[2] === 0x46 && b[3] === 0x46) return 'wav';
  // OGG: OggS
  if (b[0] === 0x4f && b[1] === 0x67 && b[2] === 0x67 && b[3] === 0x53) return 'ogg';
  // FLAC: fLaC
  if (b[0] === 0x66 && b[1] === 0x4c && b[2] === 0x61 && b[3] === 0x43) return 'flac';
  // 감지 실패 시 확장자 그대로 사용
  return null;
}

const SUMMARY_PROMPT = `당신은 할머니, 할아버지를 위한 진료 내용 설명 도우미입니다.

【1단계】 아래 텍스트가 실제 의사-환자 진료 대화인지 판단하세요.
진료 대화가 아닌 경우(인사말, 잡담, 테스트, 의미없는 소음 등)에는 반드시 아래 JSON만 반환하세요:
{"is_medical":false,"diagnosis":null,"medications":[],"precautions":[],"next_visit":null,"summary":"진료 내용이 감지되지 않았습니다. 실제 진료 녹음을 업로드해주세요."}

【2단계】 진료 대화가 맞으면 아래 규칙을 철저히 따라 JSON으로만 응답하세요.

═══ 핵심 작성 원칙 ═══
● 절대로 의학 전문 용어를 그대로 쓰지 마세요.
  - "상기도 감염" → "목, 코, 기관지 감기"
  - "위장관염" → "배탈, 장염"
  - "고혈압성 위기" → "혈압이 매우 높이 올라간 상태"
  - "요추 추간판 탈출증" → "허리 디스크 (허리뼈 사이 쿠션이 삐져나온 것)"
  - "당뇨병성 신경병증" → "당뇨로 인해 손발 저림이나 통증이 생긴 것"
  - "심방세동" → "심장이 불규칙하게 뛰는 병"
  모르는 용어가 나오면 "쉬운 말(어려운 원래 말)" 형식으로 쓰세요.

● diagnosis: 병명을 쉬운 말로 설명하고, 왜 그런 증상이 생겼는지 1~2문장으로 풀어주세요.
  예) "코와 목에 바이러스 감기가 걸렸습니다. 기침, 콧물, 열이 나는 흔한 감기입니다."

● medications: 약 이름이 대화에서 한 번이라도 나오면 반드시 추가하세요.
  - name: 약 이름 (정확히 모르면 "의사가 처방한 감기약"처럼 유추해서 쓰세요)
  - schedule: 반드시 한국어로 → "아침", "아침, 저녁", "하루 3번 식후", "취침 전"
  - caution: 약 먹을 때 주의할 점을 쉬운 말로. 없으면 null.
  - '없음', '-', 'null' 등은 절대 약 이름으로 쓰지 마세요.

● precautions: 환자가 집에서 해야 할 일, 피해야 할 것을 쉬운 말로.
  예) "찬 음식과 찬 음료는 피하세요", "하루 1.5리터 이상 물을 마시세요"

● summary: 오늘 진료를 한 문장으로 요약. 어르신도 바로 이해할 수 있게.
  예) "코와 목 감기로 3일치 약을 받았고, 3일 후 다시 오셔야 합니다."

{
  "is_medical": true,
  "diagnosis": "쉬운 말로 설명한 진단 내용 (1~2문장)",
  "medications": [
    {
      "name": "약 이름",
      "schedule": "복용 시간",
      "caution": "주의사항 또는 null"
    }
  ],
  "precautions": ["집에서 주의할 점1", "집에서 주의할 점2"],
  "next_visit": "다음 진료 일정 (예: 3일 뒤, 1주일 후) 또는 null",
  "summary": "오늘 진료 한 줄 요약"
}`;

// ─────────────────────────────────────────
// 컨트롤러
// ─────────────────────────────────────────

/**
 * GET /doctor-note/presigned-url?ext=mp3
 * Presigned PUT URL 발급 (클라이언트가 직접 S3에 업로드)
 */
async function getPresignedUrl(req, res) {
  const ext = (req.query.ext || 'mp3').toLowerCase();
  const allowedExt = ['mp3', 'm4a', 'mp4', 'wav', 'webm', 'ogg', 'flac'];
  if (!allowedExt.includes(ext)) {
    return res.status(400).json({
      success: false,
      message: `지원하지 않는 확장자입니다. 지원 형식: ${allowedExt.join(', ')}`,
    });
  }

  const mimeMap = {
    'm4a': 'audio/mp4', 'mp3': 'audio/mpeg', 'mp4': 'audio/mp4',
    'wav': 'audio/wav', 'webm': 'audio/webm', 'ogg': 'audio/ogg', 'flac': 'audio/flac',
  };
  const contentType = mimeMap[ext];
  const s3Key = `recordings/user_${req.user.id}/${Date.now()}.${ext}`;

  try {
    const { uploadUrl, fileUrl } = await getPresignedUploadUrl(s3Key, contentType);
    return res.json({
      success: true,
      data: {
        upload_url:   uploadUrl,   // 클라이언트가 PUT 요청할 URL (5분 유효)
        s3_key:       s3Key,       // 업로드 후 /process 에 전달할 키
        file_url:     fileUrl,     // 업로드 완료 후 최종 S3 URL
        expires_in:   300,
        content_type: contentType,
      },
    });
  } catch (err) {
    console.error('[getPresignedUrl 오류]', err.message);
    return res.status(500).json({ success: false, message: '업로드 URL 생성에 실패했습니다.' });
  }
}

/**
 * POST /doctor-note/process
 * body: { s3_key, visit_date }
 *
 * 흐름: S3에서 오디오 다운로드 → Whisper(STT) → GPT(요약) → DB 저장
 */
async function processDoctorNote(req, res) {
  const { s3_key, visit_date } = req.body;

  if (!s3_key) {
    return res.status(400).json({ success: false, message: 's3_key가 필요합니다.' });
  }

  const visitDate = visit_date || null;

  try {
    console.log(`[processDoctorNote] 시작 - user_id=${req.user.id}, s3_key=${s3_key}`);

    // ── STEP 1: S3에서 오디오 다운로드 ──
    const audioBuffer = await downloadFromS3(s3_key);
    console.log(`[processDoctorNote] S3 다운로드 완료 - ${audioBuffer.length} bytes`);
    const audioUrl    = `https://${process.env.AWS_S3_BUCKET}.s3.${process.env.AWS_REGION}.amazonaws.com/${s3_key}`;

    // 매직 바이트로 실제 포맷 감지
    const originalExt = s3_key.split('.').pop().toLowerCase();
    const detectedExt = detectAudioFormat(audioBuffer) || originalExt;
    const mimeMap = {
      'm4a': 'audio/mp4', 'mp3': 'audio/mpeg', 'mp4': 'audio/mp4',
      'wav': 'audio/wav', 'webm': 'audio/webm', 'ogg': 'audio/ogg', 'flac': 'audio/flac',
    };
    const mimeType = mimeMap[detectedExt] || 'audio/mp4';

    // ── STEP 2: Whisper로 음성 → 텍스트 변환 ──
    const form = new FormData();
    form.append('file', audioBuffer, {
      filename:    `audio.${detectedExt}`,
      contentType: mimeType,
      knownLength: audioBuffer.length,
    });
    form.append('model',    'whisper-1');
    form.append('language', 'ko');

    let originalText;
    try {
      const whisperRes = await axios.post(
        'https://api.openai.com/v1/audio/transcriptions',
        form,
        {
          headers: {
            ...form.getHeaders(),
            Authorization: `Bearer ${process.env.OPENAI_API_KEY}`,
          },
          maxBodyLength: Infinity,
          maxContentLength: Infinity,
        }
      );
      originalText = whisperRes.data.text;
    } catch (axiosErr) {
      console.error('[Whisper 오류]', JSON.stringify(axiosErr.response?.data, null, 2));
      throw axiosErr;
    }

    if (!originalText || originalText.trim() === '') {
      return res.status(422).json({
        success: false,
        message: '음성에서 텍스트를 인식하지 못했습니다. 더 명확하게 녹음해주세요.',
      });
    }

    // ── STEP 3: GPT로 진료 내용 요약 ──
    const completion = await openai.chat.completions.create({
      model: 'gpt-4o-mini',
      messages: [
        { role: 'system', content: SUMMARY_PROMPT },
        { role: 'user',   content: `진료 내용:\n${originalText}` },
      ],
      response_format: { type: 'json_object' },
      temperature: 0.2,
    });

    const summaryRaw = completion.choices[0].message.content;
    const summary = parseJsonObject(summaryRaw);

    if (Object.keys(summary).length === 0) {
      return res.status(502).json({
        success: false,
        message: '진료 요약 결과를 읽지 못했습니다. 다시 시도해주세요.',
      });
    }

    if (summary.is_medical === false) {
      return res.status(422).json({
        success: false,
        message: summary.summary || '진료 내용이 감지되지 않았습니다. 실제 진료 녹음을 업로드해주세요.',
        original_text: originalText,
      });
    }

    // ── STEP 4: 진료 기록 DB 저장 ──
    const [result] = await pool.query(
      `INSERT INTO doctor_notes (user_id, audio_url, original_text, summary, visit_date)
       VALUES (?, ?, ?, ?, ?)`,
      [req.user.id, audioUrl, originalText, JSON.stringify(summary), visitDate]
    );
    const noteId = result.insertId;

    // ── STEP 5: 복용 일정 후보 목록 구성 (DB 저장 없이 제안만) ──
    const medications = summary.medications || [];
    const INVALID_NAMES = new Set(['없음', '해당 없음', '없음.', 'null', 'n/a', '-', '처방 없음', '약 없음']);
    const proposedSchedules = medications
      .filter(med => {
        if (!med.name) return false;
        const name = med.name.trim().toLowerCase();
        return name.length > 0 && !INVALID_NAMES.has(name);
      })
      .map(med => ({
        medicine_name: med.name,
        schedule_text: med.schedule || null,
        caution: med.caution || null,
      }));

    return res.json({
      success: true,
      data: {
        id:            noteId,
        visit_date:    visitDate,
        audio_url:     audioUrl,
        original_text: originalText,
        summary: {
          diagnosis:    summary.diagnosis   || null,
          medications:  summary.medications || [],
          precautions:  summary.precautions || [],
          next_visit:   summary.next_visit  || null,
          summary:      summary.summary     || null,
        },
        proposed_schedules: proposedSchedules,
        created_at: new Date(Date.now() + 9 * 60 * 60 * 1000)
                      .toISOString().replace('T', ' ').substring(0, 19),
      },
    });
  } catch (err) {
    console.error('[processDoctorNote 오류]', err.message);
    return res.status(500).json({
      success: false,
      message: '진료 내용 분석 중 오류가 발생했습니다.',
      error: err.message,
    });
  }
}

/**
 * GET /doctor-note
 * 내 진료 기록 목록 조회
 */
async function getDoctorNotes(req, res) {
  const limit = Math.min(parseInt(req.query.limit, 10) || 10, 50);

  try {
    const [rows] = await pool.query(
      `SELECT id, summary, visit_date, created_at
       FROM doctor_notes
       WHERE user_id = ?
       ORDER BY created_at DESC
       LIMIT ?`,
      [req.user.id, limit]
    );

    const notes = rows.map((row) => ({
      id:         row.id,
      visit_date: row.visit_date,
      summary:    parseJsonObject(row.summary),
      created_at: row.created_at,
    }));

    return res.json({ success: true, data: notes });
  } catch (err) {
    console.error('[getDoctorNotes 오류]', err.message);
    return res.status(500).json({ success: false, message: '서버 오류가 발생했습니다.' });
  }
}

/**
 * GET /doctor-note/:id
 * 특정 진료 기록 상세 조회 (원문 포함)
 */
async function getDoctorNoteById(req, res) {
  const { id } = req.params;

  try {
    const [rows] = await pool.query(
      `SELECT * FROM doctor_notes WHERE id = ? AND user_id = ?`,
      [id, req.user.id]
    );

    if (rows.length === 0) {
      return res.status(404).json({ success: false, message: '진료 기록을 찾을 수 없습니다.' });
    }

    const row = rows[0];
    return res.json({
      success: true,
      data: {
        id:            row.id,
        visit_date:    row.visit_date,
        original_text: row.original_text,
        summary:       parseJsonObject(row.summary),
        created_at:    row.created_at,
      },
    });
  } catch (err) {
    console.error('[getDoctorNoteById 오류]', err.message);
    return res.status(500).json({ success: false, message: '서버 오류가 발생했습니다.' });
  }
}

/**
 * DELETE /doctor-note/:id
 * 진료 기록 삭제
 */
async function deleteDoctorNote(req, res) {
  const { id } = req.params;

  try {
    const [rows] = await pool.query(
      'SELECT id, audio_url FROM doctor_notes WHERE id = ? AND user_id = ?',
      [id, req.user.id]
    );
    if (rows.length === 0) {
      return res.status(404).json({ success: false, message: '진료 기록을 찾을 수 없습니다.' });
    }

    const audioUrl = rows[0].audio_url;

    // S3에서 오디오 파일 삭제 (실패해도 DB 삭제는 진행)
    if (audioUrl) {
      try {
        // https://bucket.s3.region.amazonaws.com/recordings/... 에서 key 추출
        const url = new URL(audioUrl);
        const s3Key = url.pathname.replace(/^\//, '');
        await deleteFromS3(s3Key);
        console.log(`[deleteDoctorNote] S3 파일 삭제 완료: ${s3Key}`);
      } catch (s3Err) {
        console.warn(`[deleteDoctorNote] S3 삭제 실패 (DB 삭제 계속): ${s3Err.message}`);
      }
    }

    await pool.query('DELETE FROM doctor_notes WHERE id = ?', [id]);
    return res.json({ success: true, message: '진료 기록이 삭제되었습니다.' });
  } catch (err) {
    console.error('[deleteDoctorNote 오류]', err.message);
    return res.status(500).json({ success: false, message: '서버 오류가 발생했습니다.' });
  }
}

module.exports = { getPresignedUrl, processDoctorNote, getDoctorNotes, getDoctorNoteById, deleteDoctorNote };
