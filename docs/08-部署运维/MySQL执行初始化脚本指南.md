# 在 MySQL 中执行初始化脚本

## 方法一：使用 mysql 命令行

```bash
# 连接到 MySQL
mysql -u root -p

# 输入密码后，执行初始化脚本
source /root/IoT_Smart_Hotel_System/backend/iot-hotel-backend/database/init.sql

# 或者使用绝对路径
source /root/IoT_Smart_Hotel_System/backend/iot-hotel-backend/database/init.sql;
```

## 方法二：使用 cat 管道

```bash
# 直接执行 SQL 文件
cat /root/IoT_Smart_Hotel_System/backend/iot-hotel-backend/database/init.sql | mysql -u root -p

# 或者指定数据库
cat /root/IoT_Smart_Hotel_System/backend/iot-hotel-backend/database/init.sql | mysql -u root -p iot_hotel_system
```

## 方法三：使用 mysql 命令直接执行

```bash
# 执行 SQL 文件
mysql -u root -p < /root/IoT_Smart_Hotel_System/backend/iot-hotel-backend/database/init.sql

# 指定数据库
mysql -u root -p iot_hotel_system < /root/IoT_Smart_Hotel_System/backend/iot-hotel-backend/database/init.sql
```

## 方法四：在 MySQL 客户端中执行

```bash
# 连接到 MySQL
mysql -u root -p

# 在 MySQL 提示符下执行
mysql> source /root/IoT_Smart_Hotel_System/backend/iot-hotel-backend/database/init.sql;
```

## 方法五：使用 docker 执行（如果使用 Docker）

```bash
# 进入 MySQL 容器
docker exec -it mysql-container mysql -u root -p

# 在容器内执行
mysql> source /docker-entrypoint-initdb.d/init.sql;
```

## 执行后验证

```bash
# 连接到 MySQL
mysql -u root -p

# 查看数据库
SHOW DATABASES;

# 选择数据库
USE iot_hotel_system;

# 查看表
SHOW TABLES;

# 检查表数据
SELECT * FROM hotels;
SELECT * FROM rooms;
```

## 快速执行命令（复制粘贴）

```bash
# 执行初始化脚本
mysql -u root -p < /root/IoT_Smart_Hotel_System/backend/iot-hotel-backend/database/init.sql

# 验证
mysql -u root -p -e "USE iot_hotel_system; SHOW TABLES;"
```

## 注意事项

1. **权限问题：** 确保 MySQL 用户有创建数据库和表的权限
2. **数据库已存在：** 如果数据库已存在，脚本会先删除再重建
3. **数据备份：** 执行前建议备份现有数据
4. **字符集：** 脚本使用 utf8mb4 字符集

## 自动化脚本

```bash
#!/bin/bash

echo "=== 执行数据库初始化脚本 ==="

# 1. 备份现有数据库（可选）
echo "备份现有数据库..."
mysqldump -u root -p iot_hotel_system > /tmp/iot_hotel_system_backup.sql 2>/dev/null || echo "无现有数据库可备份"

# 2. 执行初始化脚本
echo "执行初始化脚本..."
mysql -u root -p < /root/IoT_Smart_Hotel_System/backend/iot-hotel-backend/database/init.sql

# 3. 验证
echo "验证表创建..."
mysql -u root -p -e "USE iot_hotel_system; SHOW TABLES;"

echo "=== 初始化完成 ==="
```
