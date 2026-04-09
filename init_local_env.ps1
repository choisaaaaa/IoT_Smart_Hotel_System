# 启动数据库和中间件 (MySQL, Redis, MQTT)
Write-Host "Starting Docker services (MySQL, Redis, MQTT)..." -ForegroundColor Green
cd docker
docker-compose up -d mysql redis mqtt
cd ..

# 配置后端环境变量
Write-Host "Configuring Backend..." -ForegroundColor Green
cd backend/iot-hotel-backend
if (-Not (Test-Path ".env")) {
    Copy-Item ".env.example" ".env"
    Write-Host "Created .env from .env.example" -ForegroundColor Cyan
}

# 安装后端依赖
Write-Host "Installing Backend Dependencies..." -ForegroundColor Green
npm install

# 安装前端依赖
Write-Host "Installing Frontend Dependencies..." -ForegroundColor Green
cd ../../frontend/iot-hotel-web
npm install

Write-Host "======================================================" -ForegroundColor Green
Write-Host "环境初始化完成！请分别开启两个新终端运行以下命令：" -ForegroundColor Yellow
Write-Host "1. 后端终端: cd backend/iot-hotel-backend && npm run dev" -ForegroundColor Cyan
Write-Host "2. 前端终端: cd frontend/iot-hotel-web && npm run dev" -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Green
