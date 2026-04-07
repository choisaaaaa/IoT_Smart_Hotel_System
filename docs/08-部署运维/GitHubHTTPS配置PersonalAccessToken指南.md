# GitHub HTTPS 方式配置 Personal Access Token

> **问题**: 使用 HTTPS 地址克隆私有仓库时需要身份验证  
> **解决方案**: 配置 GitHub Personal Access Token

---

## 📋 目录

1. [生成 Personal Access Token](#1-生成-personal-access-token)
2. [在服务器上配置 Git](#2-在服务器上配置-git)
3. [使用 Token 克隆仓库](#3-使用-token-克隆仓库)
4. [配置 Git 凭据缓存](#4-配置-git-凭据缓存)
5. [常见问题](#5-常见问题)

---

## 1. 生成 Personal Access Token

### 1.1 在 GitHub 网站上操作

1. 登录 GitHub
2. 点击右上角头像 → **Settings**
3. 左侧菜单 → **Developer settings**
4. 点击 **Personal access tokens** → **Tokens (classic)**
5. 点击 **Generate new token** → **Generate new token (classic)**

### 1.2 设置 Token 信息

**Token 信息设置**：

| 选项 | 值 | 说明 |
|------|-----|------|
| **Note** | `IoT Hotel Server` | Token 名称，方便识别 |
| **Expiration** | `90 days` | 过期时间（建议 90 天） |
| **Permissions** | `repo` | 完全控制私有仓库 |

**权限设置**：

```
✓ repo (Full control of private repositories)
  - repo:status - Access commit status
  - repo_deployment - Access deployment status
  - public_repo - Access public repositories
  - repo:invite - Access repository invitations
  - security_events - Read and write security events
```

### 1.3 生成并保存 Token

1. 点击 **Generate token**
2. **复制 Token**（只显示一次！）
3. 保存到安全的地方

**Token 格式**：
```
ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

---

## 2. 在服务器上配置 Git

### 2.1 配置 Git 用户名

```bash
# 配置 Git 用户名
git config --global user.name "Your Name"

# 配置 Git 邮箱
git config --global user.email "your_email@example.com"
```

### 2.2 配置凭据管理（可选）

```bash
# 配置凭据缓存（临时缓存）
git config --global credential.helper cache

# 或使用存储（永久保存）
git config --global credential.helper store
```

---

## 3. 使用 Token 克隆仓库

### 3.1 方法一：直接在 URL 中包含 Token

```bash
# 克隆私有仓库
cd ~
mkdir -p iot-hotel-system
cd iot-hotel-system

# 使用 HTTPS + Token
git clone https://your-username:YOUR_TOKEN@github.com/choisaaaaa/IoT_Smart_Hotel_System.git
```

**示例**：
```bash
git clone https://choisaaaaa:ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx@github.com/choisaaaaa/IoT_Smart_Hotel_System.git
```

### 3.2 方法二：使用环境变量

```bash
# 设置环境变量
export GITHUB_TOKEN="ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

# 克隆仓库
git clone https://x-access-token:${GITHUB_TOKEN}@github.com/choisaaaaa/IoT_Smart_Hotel_System.git
```

### 3.3 方法三：交互式输入（推荐用于测试）

```bash
# 克隆仓库（会提示输入密码）
git clone https://github.com/choisaaaaa/IoT_Smart_Hotel_System.git

# 当提示输入密码时，输入你的 Token
# Username: your-username (如：choisaaaaa)
# Password: ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

---

## 4. 配置 Git 凭据缓存

### 4.1 配置凭据存储

```bash
# 配置凭据存储（永久保存）
git config --global credential.helper store

# 第一次克隆时会提示输入用户名和密码
# Username: your-username
# Password: your-token
```

### 4.2 配置凭据缓存（临时）

```bash
# 配置凭据缓存（默认 15 分钟）
git config --global credential.helper cache

# 或设置自定义时间（如 1 小时）
git config --global credential.helper 'cache --timeout=3600'
```

### 4.3 清除凭据

```bash
# 清除缓存中的凭据
git credential-cache exit

# 或删除存储的凭据
rm -f ~/.git-credentials
```

---

## 5. 常见问题

### 5.1 Token 过期

**问题**: `401 Unauthorized`

**解决方案**：

```bash
# 生成新的 Token（参考第 1 节）

# 更新 Git 凭据
git credential-cache exit

# 重新克隆或拉取
git pull
```

### 5.2 权限不足

**问题**: `403 Forbidden` 或 `Repository not found`

**解决方案**：

```bash
# 检查 Token 权限
# 确保 Token 有 repo 权限

# 检查仓库访问权限
# 确保 GitHub 账号有仓库访问权限

# 重新生成 Token
# 确保勾选了 repo 权限
```

### 5.3 二步验证（MFA）问题

**问题**: 使用密码克隆失败

**解决方案**：

```bash
# 必须使用 Personal Access Token
# 不能使用账户密码

# 生成 Token（参考第 1 节）
# 使用 Token 克隆仓库
git clone https://your-username:TOKEN@github.com/choisaaaaa/IoT_Smart_Hotel_System.git
```

### 5.4 Token 泄露

**问题**: Token 被泄露

**解决方案**：

```bash
# 立即在 GitHub 上撤销 Token
# Settings → Developer settings → Personal access tokens → Revoke

# 生成新的 Token
# 更新所有使用该 Token 的地方
```

---

## 📋 推荐配置流程

### 使用 HTTPS + Token（推荐）

```bash
# 1. 在 GitHub 生成 Token（参考第 1 节）
# 保存 Token: ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# 2. 在服务器上配置 Git
git config --global user.name "Your Name"
git config --global user.email "your_email@example.com"

# 3. 配置凭据存储（推荐）
git config --global credential.helper store

# 4. 克隆仓库
cd ~
mkdir -p iot-hotel-system
cd iot-hotel-system

# 第一次克隆时会提示输入用户名和密码
git clone https://github.com/choisaaaaa/IoT_Smart_Hotel_System.git

# Username: choisaaaaa
# Password: ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# 5. 之后的操作会自动使用存储的凭据
git pull
git push
```

---

## 🔐 安全建议

1. **限制 Token 权限**
   - 只授予必要的权限
   - 使用 `repo` 权限即可

2. **设置合理的过期时间**
   - 建议 90 天
   - 定期轮换 Token

3. **保护 Token**
   - 不要将 Token 提交到仓库
   - 不要在脚本中硬编码 Token
   - 使用环境变量或凭据管理

4. **定期检查 Token**
   - 定期查看 Token 使用情况
   - 及时撤销不使用的 Token

5. **使用环境变量（CI/CD）**
   ```bash
   # 在 CI/CD 中使用环境变量
   export GITHUB_TOKEN="${{ secrets.GITHUB_TOKEN }}"
   git clone https://x-access-token:${GITHUB_TOKEN}@github.com/choisaaaaa/IoT_Smart_Hotel_System.git
   ```

---

## 🔄 Token vs SSH 密钥对比

| 特性 | Personal Access Token | SSH 密钥 |
|------|----------------------|----------|
| **安全性** | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **便利性** | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **过期时间** | 可设置（建议 90 天） | 无过期 |
| **配置复杂度** | 简单 | 中等 |
| **适合场景** | 临时部署、CI/CD | 长期部署 |
| **MFA 支持** | ✅ | ✅ |

---

## 📚 参考资料

- [GitHub Personal Access Token 文档](https://docs.github.com/zh/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens)
- [Git 凭据管理](https://git-scm.com/docs/gitcredentials)
- [GitHub CLI 文档](https://cli.github.com/manual/)

---

## 🎯 快速总结

### 生成 Token → 配置 Git → 克隆仓库

```bash
# 1. 在 GitHub 生成 Token
# Settings → Developer settings → Personal access tokens

# 2. 配置 Git
git config --global user.name "Your Name"
git config --global user.email "your_email@example.com"
git config --global credential.helper store

# 3. 克隆仓库
git clone https://github.com/choisaaaaa/IoT_Smart_Hotel_System.git
# Username: choisaaaaa
# Password: ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

---

**最后更新**: 2026-04-07
