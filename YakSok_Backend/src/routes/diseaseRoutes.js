const express = require('express');
const router = express.Router();
const { authenticate, requireRegistered } = require('../middleware/auth');
const { getDiseases, getDiseasePreventionInfo } = require('../controllers/diseaseController');

// 유행 질병 조회
router.get('/', authenticate, requireRegistered, getDiseases);

// 특정 질병 예방법/주의사항 (GPT)
router.get('/prevention', authenticate, requireRegistered, getDiseasePreventionInfo);

module.exports = router;
