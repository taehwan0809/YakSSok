const axios = require('axios');
const OpenAI = require('openai');
require('dotenv').config();

const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });

const SERVICE_KEY = process.env.PUBLIC_DATA_API_KEY;
const BASE_URL = 'https://apis.data.go.kr/1790387/EIDAPIService';

// ─────────────────────────────────────────
// 시도 코드 매핑 (searchSidoCd)
// ─────────────────────────────────────────
const SIDO_CODES = {
  '서울': '01', '서울특별시': '01',
  '부산': '02', '부산광역시': '02',
  '대구': '03', '대구광역시': '03',
  '인천': '04', '인천광역시': '04',
  '광주': '05', '광주광역시': '05',
  '대전': '06', '대전광역시': '06',
  '울산': '07', '울산광역시': '07',
  '세종': '08', '세종특별자치시': '08',
  '경기': '09', '경기도': '09',
  '강원': '10', '강원도': '10', '강원특별자치도': '10',
  '충북': '11', '충청북도': '11',
  '충남': '12', '충청남도': '12',
  '전북': '13', '전라북도': '13', '전북특별자치도': '13',
  '전남': '14', '전라남도': '14',
  '경북': '15', '경상북도': '15',
  '경남': '16', '경상남도': '16',
  '제주': '17', '제주특별자치도': '17',
};

// ─────────────────────────────────────────
// API 호출 함수
// ─────────────────────────────────────────

async function fetchRegionDisease(searchYear, searchSidoCd, numOfRows = 20) {
  const params = {
    serviceKey: SERVICE_KEY,
    resType: 2,
    searchType: 1,       // 1: 발생수
    searchYear,
    searchSidoCd,
    pageNo: 1,
    numOfRows,
  };

  const response = await axios.get(`${BASE_URL}/Region`, { params });
  const root = response.data?.response;
  const body = root?.body;

  if (!body) {
    const code = root?.header?.resultCode;
    const msg  = root?.header?.resultMsg;
    throw new Error(`API 오류 [${code}]: ${msg}`);
  }

  const items = body.items?.item;
  if (!items) throw new Error('데이터가 없습니다.');

  return Array.isArray(items) ? items : [items];
}

// ─────────────────────────────────────────
// 데이터 가공
// ─────────────────────────────────────────

// resultVal: "30,166" 또는 "0" 또는 "-"
function parseResultVal(val) {
  if (!val || val === '-') return 0;
  return parseInt(String(val).replace(/,/g, ''), 10) || 0;
}

function parseItems(items, targetSidoCd) {
  return items
    .filter((d) => {
      // 특정 지역 요청 시 해당 시도만, 없으면 전국(00)만
      if (targetSidoCd) return d.sidoCd === targetSidoCd;
      return d.sidoCd === '00';
    })
    .map((d) => ({
      name:   d.icdNm    || '알 수 없음',
      grade:  d.icdGroupNm || null,
      count:  parseResultVal(d.resultVal),
      region: d.sidoNm   || null,
      year:   d.year     || null,
    }))
    .filter((d) => d.count > 0)
    .sort((a, b) => b.count - a.count);
}

// ─────────────────────────────────────────
// 컨트롤러
// ─────────────────────────────────────────

/**
 * GET /disease?region=서울&year=2024&limit=5
 *
 * region: 시도명 (서울, 부산 등) — 없으면 전국 집계
 * year:   조회 년도 (기본: 전년도)
 * limit:  결과 수 (기본 5, 최대 20)
 */
async function getDiseases(req, res) {
  const { region, limit = 5 } = req.query;
  const safeLimit = Math.min(parseInt(limit, 10) || 5, 20);

  // year 파라미터 없으면 전년도 사용 (당해 데이터 미집계 가능성)
  const kstYear = new Date(Date.now() + 9 * 60 * 60 * 1000).getUTCFullYear();
  const searchYear = req.query.year || String(kstYear - 1);

  try {
    let rawItems = [];
    let source;

    let targetSidoCd = null;

    if (region) {
      const sidoCd = SIDO_CODES[region];
      if (!sidoCd) {
        return res.status(400).json({
          success: false,
          message: `지원하지 않는 지역명입니다: '${region}'`,
          supported: Object.keys(SIDO_CODES).filter((k) => k.length <= 3),
        });
      }
      rawItems = await fetchRegionDisease(searchYear, sidoCd, 200);
      targetSidoCd = sidoCd;
      source = region;
    } else {
      // 전국(sidoCd: "00") 데이터 조회
      rawItems = await fetchRegionDisease(searchYear, '01', 200);
      targetSidoCd = null; // → parseItems에서 '00' 필터링
      source = '전국';
    }

    const parsed  = parseItems(rawItems, targetSidoCd);
    const topList = parsed.slice(0, safeLimit).map((item, idx) => ({
      rank: idx + 1,
      ...item,
    }));

    return res.json({
      success: true,
      data: {
        source,
        year: searchYear,
        total_diseases: parsed.length,
        top_diseases: topList,
        notice: '이 정보는 질병관리청 전수신고 데이터 기반이며, 의료적 진단이 아닙니다.',
      },
    });
  } catch (err) {
    console.error('[getDiseases 오류]', err.message);
    return res.status(502).json({
      success: false,
      message: '감염병 데이터를 불러오는 데 실패했습니다.',
      error: err.message,
    });
  }
}

/**
 * GET /disease/prevention?name=결핵
 * GPT로 특정 감염병 예방법 및 주의사항 조회
 */
async function getDiseasePreventionInfo(req, res) {
  const { name } = req.query;
  if (!name || !name.trim()) {
    return res.status(400).json({ success: false, message: 'name 파라미터가 필요합니다.' });
  }

  try {
    const completion = await openai.chat.completions.create({
      model: 'gpt-4o-mini',
      messages: [
        {
          role: 'system',
          content: `당신은 노인을 위한 건강 정보 제공 AI입니다.
다음 감염병에 대해 쉬운 한국어로 아래 JSON 형식으로만 답변하세요. 의학 용어는 쉬운 말로 풀어서 설명하세요.
{
  "overview": "이 질병이 무엇인지 1~2문장 설명",
  "symptoms": ["주요 증상1", "주요 증상2", "주요 증상3"],
  "prevention": ["예방법1", "예방법2", "예방법3", "예방법4"],
  "warning_signs": ["즉시 병원을 가야 하는 위험 신호1", "위험 신호2"]
}`,
        },
        {
          role: 'user',
          content: `감염병 이름: ${name.trim()}`,
        },
      ],
      response_format: { type: 'json_object' },
      temperature: 0.3,
    });

    let info = {};
    try {
      info = JSON.parse(completion.choices[0].message.content);
    } catch (_) {}

    return res.json({
      success: true,
      data: {
        name: name.trim(),
        overview: info.overview || null,
        symptoms: Array.isArray(info.symptoms) ? info.symptoms : [],
        prevention: Array.isArray(info.prevention) ? info.prevention : [],
        warning_signs: Array.isArray(info.warning_signs) ? info.warning_signs : [],
      },
    });
  } catch (err) {
    console.error('[getDiseasePreventionInfo 오류]', err.message);
    return res.status(500).json({
      success: false,
      message: '예방 정보를 불러오는 데 실패했습니다.',
    });
  }
}

module.exports = { getDiseases, getDiseasePreventionInfo };
