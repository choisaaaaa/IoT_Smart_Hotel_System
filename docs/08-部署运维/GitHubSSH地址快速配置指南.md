# GitHub 私有仓库 SSH 地址快速配置

> **问题**: `git pull` 时提示输入 HTTPS 用户名和密码  
> **解决方案**: 将远程仓库地址从 HTTPS 改为 SSH

---

## 🚀 快速解决方案（覆写远程地址）

### 步骤 1：查看当前远程地址

```bash
# 查看当前远程仓库地址
git remote -v
```

**当前输出**（HTTPS 地址）：
```
origin  https://github.com/choisaaaaa/IoT_Smart_Hotel_System.git (fetch)
origin  https://github.com/choisaaaaa/IoT_Smart_Hotel_System.git (push)
```

### 步骤 2：覆写为 SSH 地址

```bash
# 覆写远程地址为 SSH
git remote set-url origin git@github.com:choisaaaaa/IoT_Smart_Hotel_System.git

# 或者先删除再添加
git remote remove origin
git remote add origin git@github.com:choisaaaaa/IoT_Smart_Hotel_System.git
```

### 步骤 3：验证地址已更改

```bash
# 查看远程地址
git remote -v
```

**预期输出**（SSH 地址）：
```
origin  git@github.com:choisaaaaa/IoT_Smart_Hotel_System.git (fetch)
origin  git@github.com:choisaaaaa/IoT_Smart_Hotel_System.git (push)
```

### 步骤 4：测试拉取

```bash
# 测试拉取
git pull
```

**预期输出**：
```
Already up to date.
```

---

## 🔧 完整配置流程

### 1. 生成 SSH 密钥（如果还没有）

```bash
# 在服务器上生成 SSH 密钥
ssh-keygen -t ed25519 -C "iot-hotel-server"

# 按提示操作，直接回车使用默认路径
```

### 2. 添加公钥到 GitHub

```bash
# 查看公钥内容
cat ~/.ssh/id_ed25519.pub

# 复制内容到 GitHub
# Settings → SSH and GPG keys → New SSH key
```

### 3. 配置 SSH

```bash
# 创建 SSH 配置
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# 创建 config 文件
vim ~/.ssh/config
```

**配置内容**：

```
Host github.com
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_ed25519
  IdentitiesOnly yes
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
```

### 4. 测试连接

```bash
# 测试 GitHub 连接
ssh -T github.com
```

**预期输出**：
```
Hi choisaaaaa! You've successfully authenticated, but GitHub does not provide shell access.
```

### 5. 配置 Git 用户

```bash
# 配置 Git 用户名
git config --global user.name "Your Name"

# 配置 Git 邮箱
git config --global user.email "your_email@example.com"
```

### 6. 克隆或拉取

```bash
# 如果是新项目，克隆
git clone git@github.com:choisaaaaa/IoT_Smart_Hotel_System.git

# 如果是已有项目，直接拉取
git pull
```

---

## 📝 一键脚本

```bash
#!/bin/bash

echo "=== 配置 GitHub SSH 远程地址 ==="

# 检查是否在 Git 项目目录
if [ ! -d ".git" ]; then
    echo "错误：当前目录不是 Git 项目"
    exit 1
fi

# 备份当前远程地址
echo "备份当前远程地址..."
git remote -v > /tmp/remote_backup.txt

# 覆写为 SSH 地址
echo "配置 SSH 远程地址..."
git remote set-url origin git@github.com:choisaaaaa/IoT_Smart_Hotel_System.git

# 验证
echo "验证远程地址..."
git remote -v

echo "=== 配置完成 ==="
echo "现在可以执行 git pull 或 git push"
```

---

## 🎯 验证配置

### 1. 测试 SSH 连接

```bash
ssh -T github.com
```

### 2. 测试 Git 拉取

```bash
git pull
```

### 3. 测试 Git 推送

```bash
git push
```

---

## ⚠️ 常见问题

### 问题 1：Permission denied (publickey)

**解决方案**：

```bash
# 检查 SSH 密钥是否存在
ls -la ~/.ssh

# 检查 SSH 配置
cat ~/.ssh/config

# 测试 SSH 连接（详细模式）
ssh -vT github.com
```

### 问题 2：Repository not found

**解决方案**：

```bash
# 检查仓库地址
git remote -v

# 确保仓库地址正确
git remote set-url origin git@github.com:choisaaaaa/IoT_Smart_Hotel_System.git

# 检查 GitHub 密钥是否添加
ssh -T github.com
```

### 问题 3：Still asking for password

**解决方案**：

```bash
# 检查远程地址是否已更改为 SSH
git remote -v

# 如果还是 HTTPS，重新设置
git remote set-url origin git@github.com:choisaaaaa/IoT_Smart_Hotel_System.git

# 清除 Git 凭据缓存
git credential-cache exit
```

---

## 📋 配置检查清单

- [ ] SSH 密钥已生成
- [ ] 公钥已添加到 GitHub
- [ ] SSH 配置已创建
- [ ] 远程地址已更改为 SSH
- [ ] SSH 连接测试通过
- [ ] Git pull 测试通过
- [ ] Git push 测试通过

---

## 🔄 从 HTTPS 切换到 SSH 的原因

| 原因 | 说明 |
|------|------|
| **安全性** | SSH 密钥比密码更安全 |
| **便利性** | 无需每次输入密码 |
| **自动化** | 适合 CI/CD 和自动化部署 |
| **稳定性** | 不会因密码过期而失效 |

---

## 📚 参考资料

- [GitHub SSH 密钥文档](https://docs.github.com/zh/authentication/connecting-to-github-with-ssh)
- [Git 远程仓库管理](https://git-scm.com/book/zh/v2/Git-%E5%9F%BA%E7%A1%80-%E6%B7%BB%E5%8A%A0%E8%BF%9C%E7%A8%8B%E4%BB%93%E5%BA%93)

---

**最后更新**: 2026-04-07
