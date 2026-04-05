const axios = require('axios');
const { latLngToGrid } = require('../utils/gridConverter');
require('dotenv').config();

const SERVICE_KEY = process.env.PUBLIC_DATA_API_KEY;

// ─────────────────────────────────────────
// 코드 → 텍스트 변환 테이블
// ─────────────────────────────────────────

const SKY_CODE = { 1: '맑음', 3: '구름많음', 4: '흐림' };
const PTY_CODE = { 0: '없음', 1: '비', 2: '비/눈', 3: '눈', 4: '소나기' };
const GRADE_CODE = { 1: '좋음', 2: '보통', 3: '나쁨', 4: '매우나쁨' };
const GRADE_EMOJI = { 1: '😊', 2: '🙂', 3: '😷', 4: '🚫' };

// PM10 등급 기준 (㎍/㎥)
function getPm10Grade(value) {
  if (value === null || value === '-') return null;
  const v = Number(value);
  if (v <= 30) return 1;
  if (v <= 80) return 2;
  if (v <= 150) return 3;
  return 4;
}

// PM2.5 등급 기준 (㎍/㎥)
function getPm25Grade(value) {
  if (value === null || value === '-') return null;
  const v = Number(value);
  if (v <= 15) return 1;
  if (v <= 35) return 2;
  if (v <= 75) return 3;
  return 4;
}

// ─────────────────────────────────────────
// 기상청 base_date, base_time 계산
// ─────────────────────────────────────────

function getBaseDateTime() {
  // KST (UTC+9)
  const now = new Date(Date.now() + 9 * 60 * 60 * 1000);
  const hour = now.getUTCHours();
  const minute = now.getUTCMinutes();

  // 예보 발표 시각 (10분 이후 데이터 안정)
  const baseTimes = [2, 5, 8, 11, 14, 17, 20, 23];

  let baseHour = 23;
  let dayOffset = -1; // 기본값: 전날 23시

  for (let i = baseTimes.length - 1; i >= 0; i--) {
    if (hour > baseTimes[i] || (hour === baseTimes[i] && minute >= 10)) {
      baseHour = baseTimes[i];
      dayOffset = 0;
      break;
    }
  }

  const baseDate = new Date(now.getTime() + dayOffset * 24 * 60 * 60 * 1000);
  const yyyy = baseDate.getUTCFullYear();
  const mm = String(baseDate.getUTCMonth() + 1).padStart(2, '0');
  const dd = String(baseDate.getUTCDate()).padStart(2, '0');

  return {
    base_date: `${yyyy}${mm}${dd}`,
    base_time: String(baseHour).padStart(2, '0') + '00',
  };
}

// ─────────────────────────────────────────
// 기상청 단기예보 API 호출
// ─────────────────────────────────────────

async function fetchWeatherForecast(nx, ny) {
  const { base_date, base_time } = getBaseDateTime();

  const url = 'http://apis.data.go.kr/1360000/VilageFcstInfoService_2.0/getVilageFcst';
  const params = {
    serviceKey: SERVICE_KEY,
    pageNo: 1,
    numOfRows: 300,
    dataType: 'JSON',
    base_date,
    base_time,
    nx,
    ny,
  };

  const response = await axios.get(url, { params });
  const items = response.data?.response?.body?.items?.item;

  if (!items || !Array.isArray(items)) {
    throw new Error('기상청 API 응답 오류');
  }

  // KST 현재 시각
  const now = new Date(Date.now() + 9 * 60 * 60 * 1000);
  const currentHour = now.getUTCHours();
  const currentMin  = now.getUTCMinutes();
  const currentDate = `${now.getUTCFullYear()}${String(now.getUTCMonth() + 1).padStart(2, '0')}${String(now.getUTCDate()).padStart(2, '0')}`;
  const currentHourStr = String(currentHour).padStart(2, '0') + (currentMin >= 30 ? '30' : '00');
  const currentDateHour = currentDate + String(currentHour).padStart(2, '0') + '00';

  // fcstDate + fcstTime 조합 중 현재 이후 가장 가까운 것 선택
  const pairs = [...new Set(items.map((i) => i.fcstDate + i.fcstTime))].sort();
  const targetPair = pairs.find((p) => p >= currentDateHour) || pairs[0];
  const targetDate = targetPair.substring(0, 8);
  const targetTime = targetPair.substring(8);

  // 해당 시각 예보 추출
  const current = {};
  items
    .filter((i) => i.fcstDate === targetDate && i.fcstTime === targetTime)
    .forEach((i) => {
      current[i.category] = i.fcstValue;
    });

  // 오늘 최고/최저 기온 (없으면 내일 것)
  const tmxItem = items.find((i) => i.fcstDate === currentDate && i.category === 'TMX')
    || items.find((i) => i.category === 'TMX');
  const tmnItem = items.find((i) => i.fcstDate === currentDate && i.category === 'TMN')
    || items.find((i) => i.category === 'TMN');

  return {
    base_date,
    base_time,
    fcst_time: targetTime,
    temperature: current.TMP ? `${current.TMP}°C` : null,
    temp_max: tmxItem ? `${tmxItem.fcstValue}°C` : null,
    temp_min: tmnItem ? `${tmnItem.fcstValue}°C` : null,
    sky: SKY_CODE[current.SKY] || null,
    precipitation_type: PTY_CODE[current.PTY] || null,
    precipitation_prob: current.POP ? `${current.POP}%` : null,
    humidity: current.REH ? `${current.REH}%` : null,
    wind_speed: current.WSD ? `${current.WSD}m/s` : null,
  };
}

// ─────────────────────────────────────────
// 에어코리아 대기오염 API 호출
// ─────────────────────────────────────────

function resolveStationCandidates(stationName) {
  const raw = String(stationName || '').trim();
  if (!raw) {
    return [];
  }

  const normalized = raw.replace(/[(),]/g, ' ');
  const segments = normalized.split(/\s+/).map((item) => item.trim()).filter(Boolean);
  const filtered = segments.filter((item) => {
    return !(
      item.endsWith('특별시') ||
      item.endsWith('광역시') ||
      item.endsWith('특별자치시') ||
      item.endsWith('특별자치도') ||
      (item.endsWith('도') && !item.endsWith('동'))
    );
  });

  const districtFirst = [
    ...filtered.filter((item) => item.endsWith('구') || item.endsWith('군')),
    ...filtered.filter((item) => item.endsWith('읍') || item.endsWith('면')),
    ...filtered.filter((item) => item.endsWith('시')),
    ...filtered.filter((item) => item.endsWith('동')),
  ];

  const aliases = [
    raw,
    ...districtFirst,
    normalized.replace('특별시', '').trim(),
    normalized.replace('광역시', '').trim(),
    normalized.replace('특별자치시', '').trim(),
  ].filter(Boolean);

  return [...new Set(aliases)];
}

async function fetchAirQuality(stationName) {
  const url = 'http://apis.data.go.kr/B552584/ArpltnInforInqireSvc/getMsrstnAcctoRltmMesureDnsty';
  const candidates = resolveStationCandidates(stationName);
  let lastError = null;

  for (const candidate of candidates) {
    try {
      const params = {
        serviceKey: SERVICE_KEY,
        returnType: 'json',
        numOfRows: 1,
        pageNo: 1,
        stationName: candidate,
        dataTerm: 'DAILY',
        ver: '1.3',
      };

      const response = await axios.get(url, { params });
      const items = response.data?.response?.body?.items;

      if (!items || items.length === 0) {
        lastError = new Error(`측정소 '${candidate}'의 데이터를 찾을 수 없습니다.`);
        continue;
      }

      const d = items[0];
      const pm10Grade = Number(d.pm10Grade) || getPm10Grade(d.pm10Value);
      const pm25Grade = Number(d.pm25Grade) || getPm25Grade(d.pm25Value);

      return {
        station_name: candidate,
        measured_at: d.dataTime || null,
        pm10: {
          value: d.pm10Value !== '-' ? `${d.pm10Value}㎍/㎥` : '측정 중',
          grade: GRADE_CODE[pm10Grade] || null,
          emoji: GRADE_EMOJI[pm10Grade] || null,
        },
        pm25: {
          value: d.pm25Value !== '-' ? `${d.pm25Value}㎍/㎥` : '측정 중',
          grade: GRADE_CODE[pm25Grade] || null,
          emoji: GRADE_EMOJI[pm25Grade] || null,
        },
        khai: {
          value: d.khaiValue !== '-' ? d.khaiValue : null,
          grade: GRADE_CODE[Number(d.khaiGrade)] || null,
          emoji: GRADE_EMOJI[Number(d.khaiGrade)] || null,
        },
        o3: d.o3Value !== '-' ? `${d.o3Value}ppm` : '측정 중',
        no2: d.no2Value !== '-' ? `${d.no2Value}ppm` : '측정 중',
      };
    } catch (error) {
      lastError = error;
    }
  }

  throw lastError || new Error(`측정소 '${stationName}'의 데이터를 찾을 수 없습니다.`);
}

// ─────────────────────────────────────────
// 건강 조언 생성 (노인 친화적)
// ─────────────────────────────────────────

function generateHealthAdvice(weather, air) {
  const advices = [];

  // 미세먼지 조언
  if (air) {
    const pm10Grade = Object.keys(GRADE_CODE).find((k) => GRADE_CODE[k] === air.pm10.grade);
    const pm25Grade = Object.keys(GRADE_CODE).find((k) => GRADE_CODE[k] === air.pm25.grade);
    const worstGrade = Math.max(Number(pm10Grade) || 0, Number(pm25Grade) || 0);

    if (worstGrade >= 4) advices.push('대기질이 매우 나쁩니다. 오늘은 외출을 자제하세요.');
    else if (worstGrade === 3) advices.push('미세먼지가 나쁩니다. 외출 시 반드시 마스크를 착용하세요.');
    else if (worstGrade === 2) advices.push('미세먼지 농도가 보통입니다. 장시간 외출 시 마스크를 챙기세요.');
    else advices.push('대기질이 좋습니다. 환기를 시켜도 좋습니다.');
  }

  // 날씨 조언
  if (weather) {
    const pty = weather.precipitation_type;
    const temp = parseFloat(weather.temperature);

    if (pty === '비' || pty === '소나기') advices.push('비가 내립니다. 우산을 꼭 챙기세요.');
    else if (pty === '눈' || pty === '비/눈') advices.push('눈이 내립니다. 낙상에 주의하세요.');

    if (!isNaN(temp)) {
      if (temp <= 0) {
        advices.push('기온이 매우 낮습니다. 패딩이나 두꺼운 외투를 입고, 모자와 장갑도 챙기세요.');
      } else if (temp <= 10) {
        advices.push('날씨가 쌀쌀합니다. 따뜻한 겉옷이나 자켓을 꼭 챙기세요.');
      } else if (temp <= 17) {
        advices.push('선선한 날씨입니다. 가벼운 겉옷 하나를 챙기시면 좋습니다.');
      } else if (temp <= 23) {
        advices.push('활동하기 좋은 날씨입니다. 긴팔 옷이 적당합니다.');
      } else if (temp <= 27) {
        advices.push('따뜻한 날씨입니다. 반팔이 적당합니다.');
      } else if (temp >= 33) {
        advices.push('매우 더운 날씨입니다. 얇고 통풍이 잘 되는 옷을 입고, 자외선 차단제를 꼭 바르세요.');
      } else {
        advices.push('더운 날씨입니다. 물을 자주 마시고 무더운 시간대 외출은 자제하세요.');
      }
    }
  }

  return advices.length > 0 ? advices : ['오늘도 건강한 하루 보내세요.'];
}

// ─────────────────────────────────────────
// 컨트롤러
// ─────────────────────────────────────────

/**
 * GET /weather?lat=37.5665&lng=126.9780&stationName=종로구
 */
async function getWeather(req, res) {
  const { lat, lng, stationName } = req.query;

  if (!lat || !lng || !stationName) {
    return res.status(400).json({
      success: false,
      message: '필수 파라미터가 없습니다.',
      required: { lat: '위도 (예: 37.5665)', lng: '경도 (예: 126.9780)', stationName: '측정소명 (예: 종로구)' },
    });
  }

  const { nx, ny } = latLngToGrid(parseFloat(lat), parseFloat(lng));

  const [weatherResult, airResult] = await Promise.allSettled([
    fetchWeatherForecast(nx, ny),
    fetchAirQuality(stationName),
  ]);

  const weather = weatherResult.status === 'fulfilled' ? weatherResult.value : null;
  const weatherError = weatherResult.status === 'rejected' ? weatherResult.reason.message : null;
  if (weatherError) console.error('[날씨 API 오류]', weatherError);

  const air = airResult.status === 'fulfilled' ? airResult.value : null;
  const airError = airResult.status === 'rejected' ? airResult.reason.message : null;
  if (airError) console.error('[대기질 API 오류]', airError);

  if (!weather && !air) {
    return res.status(502).json({
      success: false,
      message: '날씨 및 대기질 데이터를 불러오는 데 실패했습니다.',
      errors: { weather: weatherError, air: airError },
    });
  }

  const advice = generateHealthAdvice(weather, air);

  return res.json({
    success: true,
    data: {
      location: { lat: parseFloat(lat), lng: parseFloat(lng), grid: { nx, ny } },
      weather,
      air_quality: air,
      health_advice: advice,
      updated_at: new Date(Date.now() + 9 * 60 * 60 * 1000).toISOString().replace('T', ' ').substring(0, 19),
    },
    errors: {
      weather: weatherError,
      air: airError,
    },
  });
}

/**
 * GET /weather/grid?lat=37.5665&lng=126.9780
 * 위경도 → 기상청 격자 좌표 변환 유틸
 */
function getGrid(req, res) {
  const { lat, lng } = req.query;
  if (!lat || !lng) {
    return res.status(400).json({ success: false, message: 'lat, lng 파라미터가 필요합니다.' });
  }
  const grid = latLngToGrid(parseFloat(lat), parseFloat(lng));
  return res.json({ success: true, lat: parseFloat(lat), lng: parseFloat(lng), grid });
}

module.exports = { getWeather, getGrid };
