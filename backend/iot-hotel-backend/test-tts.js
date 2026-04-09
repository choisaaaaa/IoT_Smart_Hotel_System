const axios = require('axios');
const crypto = require('crypto');

async function testTTSEndToEnd() {
  console.log('🎤 测试讯飞TTS语音合成');
  console.log('');
  
  const appId = '521e128e';
  const apiKey = '8bd49f888b2b599ada8ea36742a28b37';
  const apiSecret = 'NTg0MjA2ZTNlYTRiOWZlYmRlZjRlMzJm';
  
  const url = 'https://tts-api.xfyun.cn/v2/tts';
  const date = new Date().toUTCString();
  
  // 构建签名
  const signatureOrigin = `host: tts-api.xfyun.cn\ndate: ${date}\nGET /v2/tts HTTP/1.1`;
  const signature = crypto.createHmac('sha256', apiSecret)
    .update(signatureOrigin)
    .digest('base64');
  
  const authorizationOrigin = `api_key="${apiKey}", algorithm="hmac-sha256", headers="host date request-line", signature="${signature}"`;
  const authorization = Buffer.from(authorizationOrigin).toString('base64');
  
  console.log('API:', url);
  console.log('AppID:', appId);
  console.log('Text: 您好，我是AI管家小智');
  console.log('');
  
  try {
    const startTime = Date.now();
    
    const response = await axios.post(url, {
      common: { app_id: appId },
      business: {
        aue: 'lame',
        vcn: 'xiaoyan',
        speed: 50,
        volume: 50,
        pitch: 50
      },
      data: {
        text: Buffer.from('您好，我是AI管家小智，很高兴为您服务').toString('base64'),
        status: 2
      }
    }, {
      headers: {
        'Date': date,
        'Authorization': authorization,
        'Content-Type': 'application/json'
      },
      timeout: 15000,
      responseType: 'arraybuffer'
    });
    
    const latency = Date.now() - startTime;
    
    console.log('✅ TTS调用成功！');
    console.log('⏱️ 响应时间:', latency, 'ms');
    console.log('📦 音频大小:', response.data.length, 'bytes');
    console.log('');
    
    const audioBase64 = Buffer.from(response.data).toString('base64');
    console.log('📊 Base64长度:', audioBase64.length);
    console.log('✨ 预览:', audioBase64.substring(0, 80) + '...');
    console.log('');
    console.log('═════════════════════════════════════');
    console.log('🎉 讯飞TTS验证成功！语音合成正常工作');
    console.log('═════════════════════════════════════');
    
  } catch (error) {
    console.error('❌ TTS失败:');
    if (error.response) {
      console.error('状态码:', error.response.status);
      try {
        const errText = Buffer.from(error.response.data).toString('utf8');
        console.error('错误:', errText);
      } catch(e) {
        console.error('响应大小:', error.response.data?.length);
      }
    } else {
      console.error(error.message);
    }
  }
}

testTTSEndToEnd();