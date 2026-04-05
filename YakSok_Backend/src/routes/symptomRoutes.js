const express = require('express');
const router = express.Router();
const { authenticate, requireRegistered } = require('../middleware/auth');
const { analyzeSymptom, getSymptomHistory } = require('../controllers/symptomController');
const { notifyGuardianForSymptom } = require('../controllers/notifyController');

// 증상 분석
router.post('/', authenticate, requireRegistered, analyzeSymptom);

// 분석 기록 조회
router.get('/history', authenticate, requireRegistered, getSymptomHistory);

// 보호자에게 증상 분석 결과 공유
router.post('/:id/notify', authenticate, requireRegistered, notifyGuardianForSymptom);

module.exports = router;
