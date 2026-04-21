/**
 * Postman/Newman API 测试运行器
 * 用于在命令行执行 API 测试集合并生成报告
 * 
 * 使用方法:
 * 1. 安装依赖: npm install newman newman-reporter-htmlextra
 * 2. 运行测试: node newman_runner.js
 */

const newman = require('newman');
const path = require('path');

// 测试配置
const config = {
  collection: path.join(__dirname, 'postman_collection.json'),
  environment: {
    baseUrl: process.env.API_BASE_URL || 'http://localhost:3000',
    timeout: 30000
  },
  reporters: ['cli', 'json', 'htmlextra'],
  reporter: {
    json: {
      export: path.join(__dirname, 'reports', 'api_test_results.json')
    },
    htmlextra: {
      export: path.join(__dirname, 'reports', 'api_test_report.html'),
      title: '慧宿智联 API 测试报告',
      showEnvironmentData: true,
      skipHeaders: ['Authorization']
    }
  }
};

// 确保报告目录存在
const fs = require('fs');
const reportsDir = path.join(__dirname, 'reports');
if (!fs.existsSync(reportsDir)) {
  fs.mkdirSync(reportsDir, { recursive: true });
}

console.log('🚀 开始执行 API 测试...');
console.log(`📍 目标服务器: ${config.environment.baseUrl}`);
console.log('');

// 执行测试
newman.run({
  collection: config.collection,
  reporters: config.reporters,
  reporter: config.reporter,
  timeout: {
    request: config.environment.timeout
  },
  envVar: [
    { key: 'baseUrl', value: config.environment.baseUrl }
  ]
}, function (err, summary) {
  if (err) {
    console.error('❌ 测试执行失败:', err);
    process.exit(1);
  }

  console.log('');
  console.log('📊 测试执行完成!');
  console.log('═══════════════════════════════════════');
  console.log(`总请求数: ${summary.run.stats.requests.total}`);
  console.log(`失败请求: ${summary.run.stats.requests.failed}`);
  console.log(`总测试数: ${summary.run.stats.assertions.total}`);
  console.log(`失败测试: ${summary.run.stats.assertions.failed}`);
  console.log(`平均响应时间: ${summary.run.timings.responseAverage}ms`);
  console.log('═══════════════════════════════════════');

  // 生成摘要报告
  const report = {
    timestamp: new Date().toISOString(),
    summary: {
      totalRequests: summary.run.stats.requests.total,
      failedRequests: summary.run.stats.requests.failed,
      totalAssertions: summary.run.stats.assertions.total,
      failedAssertions: summary.run.stats.assertions.failed,
      responseAverage: summary.run.timings.responseAverage,
      responseMin: summary.run.timings.responseMin,
      responseMax: summary.run.timings.responseMax
    },
    results: summary.run.executions.map(exec => ({
      name: exec.item.name,
      status: exec.response ? exec.response.code : 'N/A',
      responseTime: exec.response ? exec.response.responseTime : 0,
      tests: exec.assertions ? exec.assertions.map(a => ({
        name: a.name,
        passed: !a.error
      })) : []
    }))
  };

  // 保存详细报告
  fs.writeFileSync(
    path.join(reportsDir, 'api_test_summary.json'),
    JSON.stringify(report, null, 2)
  );

  console.log('');
  console.log('📁 报告文件:');
  console.log(`  - JSON 报告: ${config.reporter.json.export}`);
  console.log(`  - HTML 报告: ${config.reporter.htmlextra.export}`);
  console.log(`  - 摘要报告: ${path.join(reportsDir, 'api_test_summary.json')}`);

  // 如果有失败的测试，返回非零退出码
  if (summary.run.stats.assertions.failed > 0) {
    console.log('');
    console.log('⚠️  存在失败的测试用例');
    process.exit(1);
  }

  console.log('');
  console.log('✅ 所有测试通过!');
  process.exit(0);
});
