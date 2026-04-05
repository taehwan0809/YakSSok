const express = require('express');
const router  = express.Router();
const { authenticate, requireRegistered } = require('../middleware/auth');
const { notifyHealthSummary } = require('../controllers/notifyController');

// 통합 건강 알림 (최근 진료 + 증상 + 복용 일정)
router.post('/health-summary', authenticate, requireRegistered, notifyHealthSummary);

module.exports = router;
