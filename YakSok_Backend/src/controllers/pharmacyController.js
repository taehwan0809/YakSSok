const axios = require('axios');
require('dotenv').config();

const KAKAO_LOCAL_API_KEY = process.env.KAKAO_LOCAL_API_KEY;
const KAKAO_LOCAL_URL = 'https://dapi.kakao.com/v2/local/search/keyword.json';
const PHARMACY_HOURS_URL = 'https://apis.data.go.kr/B552657/ErmctInsttInfoInqireService/getParmacyListInfoInqire';
const PHARMACY_HOURS_KEY = process.env.PHARMACY_HOURS_API_KEY;

/**
 * GET /pharmacy?lat=37.5665&lng=126.9780&radius=1000&size=15
 */
async function getNearbyPharmacies(req, res) {
  const { lat, lng, radius = 1000, size = 15 } = req.query;

  if (!lat || !lng) {
    return res.status(400).json({
      success: false,
      message: '위도(lat)와 경도(lng)는 필수입니다.',
      example: '/pharmacy?lat=37.5665&lng=126.9780&radius=1000',
    });
  }

  const safeRadius = Math.min(parseInt(radius, 10) || 1000, 20000);
  const safeSize   = Math.min(parseInt(size,   10) || 15,   15);

  try {
    // ── STEP 1: 카카오 API로 주변 약국 검색 (거리 정보 포함) ──
    const kakaoRes = await axios.get(KAKAO_LOCAL_URL, {
      headers: {
        Authorization: `KakaoAK ${KAKAO_LOCAL_API_KEY}`,
        KA: 'sdk/2.7.2 os/web lang/ko origin/localhost',
      },
      params: {
        query: '약국',
        category_group_code: 'PM9',
        x: lng,
        y: lat,
        radius: safeRadius,
        sort: 'distance',
        size: safeSize,
      },
    });

    const { documents, meta } = kakaoRes.data;

    if (!documents || documents.length === 0) {
      return res.json({
        success: true,
        data: {
          total: 0,
          radius_m: safeRadius,
          pharmacies: [],
          message: `반경 ${safeRadius}m 내 약국을 찾을 수 없습니다. radius를 늘려보세요.`,
        },
      });
    }

    // ── STEP 2: 공공데이터 API로 실제 영업시간 조회 ──
    let govList = [];
    try {
      const govRes = await axios.get(PHARMACY_HOURS_URL, {
        params: {
          serviceKey: PHARMACY_HOURS_KEY,
          WGS84_LON: lng,
          WGS84_LAT: lat,
          pageNo: 1,
          numOfRows: 30,
        },
        responseType: 'text',
        timeout: 5000,
      });
      govList = parsePharmacyXml(govRes.data);
    } catch (govErr) {
      console.warn('[영업시간 API 실패, 추정값 사용]', govErr.message);
    }

    // ── STEP 3: 결과 조합 ──
    const pharmacies = documents.map((place, idx) => {
      const govMatch = matchByCoords(govList, parseFloat(place.y), parseFloat(place.x));
      const hours = govMatch ? govMatch.hours : null;
      const isOpen = hours ? checkIsOpen(hours) : estimateIsOpen();
      const todayHours = hours ? getTodayHoursText(hours) : null;

      return {
        rank:        idx + 1,
        name:        place.place_name,
        address:     place.road_address_name || place.address_name,
        phone:       place.phone || '번호 없음',
        distance_m:  parseInt(place.distance, 10),
        distance:    formatDistance(parseInt(place.distance, 10)),
        lat:         parseFloat(place.y),
        lng:         parseFloat(place.x),
        kakao_url:   place.place_url,
        is_open:     isOpen,
        today_hours: todayHours,         // 오늘 영업시간 문자열 (예: "09:00 ~ 19:00")
        hours_source: hours ? 'api' : 'estimate',
      };
    });

    return res.json({
      success: true,
      data: {
        total:    meta.total_count,
        shown:    pharmacies.length,
        radius_m: safeRadius,
        is_end:   meta.is_end,
        pharmacies,
      },
    });
  } catch (err) {
    console.error('[getNearbyPharmacies 오류]', err.response?.data || err.message);
    return res.status(502).json({
      success: false,
      message: '약국 검색 중 오류가 발생했습니다.',
      error: err.response?.data || err.message,
    });
  }
}

function formatDistance(meters) {
  if (meters < 1000) return `${meters}m`;
  return `${(meters / 1000).toFixed(1)}km`;
}

/**
 * HHMM 형식 → 분 단위 변환 (예: "0900" → 540)
 */
function hmToMinutes(hm) {
  if (!hm) return null;
  const s = String(hm).padStart(4, '0');
  const h = parseInt(s.substring(0, 2), 10);
  const m = parseInt(s.substring(2, 4), 10);
  return h * 60 + m;
}

/**
 * HHMM → "HH:MM" 표시 문자열
 */
function hmToDisplay(hm) {
  if (!hm) return null;
  const s = String(hm).padStart(4, '0');
  return `${s.substring(0, 2)}:${s.substring(2, 4)}`;
}

/**
 * 공공데이터 API 요일 키 매핑
 * API: 1=월, 2=화, 3=수, 4=목, 5=금, 6=토, 7=일
 * JS getUTCDay(): 0=일, 1=월, ..., 6=토
 */
function getDayKey() {
  const day = new Date(Date.now() + 9 * 60 * 60 * 1000).getUTCDay();
  return ['sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat'][day];
}

/**
 * 실제 영업시간 데이터로 현재 영업 여부 판단
 */
function checkIsOpen(hours) {
  const dayKey = getDayKey();
  const todaySlot = hours[dayKey];
  if (!todaySlot?.open || !todaySlot?.close) return false;

  const openMin  = hmToMinutes(todaySlot.open);
  const closeMin = hmToMinutes(todaySlot.close);
  if (openMin === null || closeMin === null) return false;

  const now = new Date(Date.now() + 9 * 60 * 60 * 1000);
  const nowMin = now.getUTCHours() * 60 + now.getUTCMinutes();
  return nowMin >= openMin && nowMin < closeMin;
}

/**
 * 오늘 영업시간 문자열 반환
 */
function getTodayHoursText(hours) {
  const dayKey = getDayKey();
  const slot = hours[dayKey];
  if (!slot?.open || !slot?.close) return '오늘 휴무';
  const open  = hmToDisplay(slot.open);
  const close = hmToDisplay(slot.close);
  if (!open || !close) return '오늘 휴무';
  return `${open} ~ ${close}`;
}

/**
 * API 실패 시 추정값 fallback
 */
function estimateIsOpen() {
  const now = new Date(Date.now() + 9 * 60 * 60 * 1000);
  const day = now.getUTCDay();
  const minutes = now.getUTCHours() * 60 + now.getUTCMinutes();
  if (day === 0) return false;
  if (day === 6) return minutes >= 9 * 60 && minutes < 13 * 60;
  return minutes >= 9 * 60 && minutes < 19 * 60;
}

/**
 * 정부 API XML 문자열에서 약국 목록을 파싱
 */
function parsePharmacyXml(xmlStr) {
  const items = [];
  const itemRegex = /<item>([\s\S]*?)<\/item>/g;
  let itemMatch;
  while ((itemMatch = itemRegex.exec(xmlStr)) !== null) {
    const block = itemMatch[1];
    const tag = (name) => {
      const m = new RegExp(`<${name}>([^<]*)</${name}>`).exec(block);
      return m ? m[1].trim() : null;
    };
    const lat = parseFloat(tag('wgs84Lat'));
    const lng = parseFloat(tag('wgs84Lon'));
    if (isNaN(lat) || isNaN(lng)) continue;
    items.push({
      name: tag('dutyName') || '',
      lat,
      lng,
      hours: {
        mon: { open: tag('dutyTime1s'), close: tag('dutyTime1c') },
        tue: { open: tag('dutyTime2s'), close: tag('dutyTime2c') },
        wed: { open: tag('dutyTime3s'), close: tag('dutyTime3c') },
        thu: { open: tag('dutyTime4s'), close: tag('dutyTime4c') },
        fri: { open: tag('dutyTime5s'), close: tag('dutyTime5c') },
        sat: { open: tag('dutyTime6s'), close: tag('dutyTime6c') },
        sun: { open: tag('dutyTime7s'), close: tag('dutyTime7c') },
        hol: { open: tag('dutyTime8s'), close: tag('dutyTime8c') },
      },
    });
  }
  return items;
}

/**
 * Haversine 공식으로 두 좌표 간 거리(미터) 계산
 */
function distanceMeters(lat1, lng1, lat2, lng2) {
  const R = 6371000;
  const toRad = (d) => (d * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

/**
 * govList에서 (lat, lng)에 가장 가까운 약국을 thresholdM 이내에서 반환
 */
function matchByCoords(govList, lat, lng, thresholdM = 200) {
  let best = null;
  let bestDist = Infinity;
  for (const item of govList) {
    const d = distanceMeters(lat, lng, item.lat, item.lng);
    if (d < bestDist) {
      bestDist = d;
      best = item;
    }
  }
  return bestDist <= thresholdM ? best : null;
}

module.exports = { getNearbyPharmacies };
