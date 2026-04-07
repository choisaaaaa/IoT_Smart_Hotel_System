# GitHub 私有仓库服务器拉取配置指南

> **版本**: v1.0.0  
> **更新日期**: 2026-04-07  
> **适用场景**: 服务器从 GitHub 私有仓库拉取代码

---

## 📋 目录

1. [方案选择](#1-方案选择)
2. [方案一：使用 SSH 密钥（推荐）](#2-方案一使用-ssh-密钥推荐)
3. [方案二：使用 Personal Access Token](#3-方案二使用-personal-access-token)
4. [方案三：使用 GitHub CLI](#4-方案三使用-github-cli)
5. [常见问题](#5-常见问题)

---

## 1. 方案选择

### 方案对比

| 方案 | 优点 | 缺点 | 推荐场景 |
|------|------|------|----------|
| **SSH 密钥** | 安全、无需频繁输入密码、支持双向认证 | 需要配置密钥对 | **服务器长期部署（推荐）** |
| **Personal Access Token** | 简单、易于管理 | Token 可能过期 | 临时部署、CI/CD |
| **GitHub CLI** | 简单、支持 MFA | 需要额外安装 | 交互式操作 |

---

## 2. 方案一：使用 SSH 密钥（推荐）

### 2.1 本地生成 SSH 密钥对

```bash
# 在本地 Windows PowerShell 中执行
ssh-keygen -t ed25519 -C "your_email@example.com"

# 或使用 RSA
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"

# 按提示操作：
# 1. Enter file in which to save the key: ~/.ssh/id_ed25519_github
# 2. Enter passphrase: (可选，建议设置)
# 3. Enter same passphrase again:
```

### 2.2 添加公钥到 GitHub

```bash
# 查看公钥内容
cat ~/.ssh/id_ed25519_github.pub

# 或使用 Windows PowerShell
Get-Content ~/.ssh/id_ed25519_github.pub | clip
```

**在 GitHub 网站上操作**：

1. 登录 GitHub
2. 点击右上角头像 → **Settings**
3. 左侧菜单 → **SSH and GPG keys**
4. 点击 **New SSH key**
5. Title: 填写服务器名称（如：`IoT Hotel Server`）
6. Key type: 选择 **Authentication Key**
7. Key: 粘贴公钥内容
8. 点击 **Add SSH key**

### 2.3 将私钥复制到服务器

```bash
# 方法 1: 使用 ssh-copy-id（推荐）
ssh-copy-id -i ~/.ssh/id_ed25519_github.pub root@8.134.166.69

# 方法 2: 手动复制
# 在本地读取公钥
cat ~/.ssh/id_ed25519_github.pub

# 在服务器上创建 authorized_keys
mkdir -p ~/.ssh
chmod 700 ~/.ssh
echo "你的公钥内容" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

### 2.4 在服务器上配置 SSH

```bash
# 在服务器上创建 SSH 配置
vim ~/.ssh/config
```

**配置内容**：

```
# GitHub SSH 配置
Host github.com
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_ed25519_github
  IdentitiesOnly yes
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
```

### 2.5 测试 SSH 连接

```bash
# 测试 GitHub 连接
ssh -T github.com

# 预期输出：
# Hi your-username! You've successfully authenticated, but GitHub does not provide shell access.
```

### 2.6 克隆私有仓库

```bash
# 克隆私有仓库
cd ~
mkdir -p iot-hotel-system
cd iot-hotel-system

# 使用 SSH 地址克隆
git clone git@github.com:choisaaaaa/IoT_Smart_Hotel_System.git

# 或使用 HTTPS 地址（需要配置 token）
# git clone https://github.com/choisaaaaa/IoT_Smart_Hotel_System.git
```

---

## 3. 方案二：使用 Personal Access Token

### 3.1 生成 GitHub Personal Access Token

**在 GitHub 网站上操作**：

1. 登录 GitHub
2. 点击右上角头像 → **Settings**
3. 左侧菜单 → **Developer settings**
4. 点击 **Personal access tokens** → **Tokens (classic)**
5. 点击 **Generate new token** → **Generate new token (classic)**
6. 设置过期时间（建议 90 天）
7. 选择权限：
   - `repo` - 完全控制私有仓库
   - `public_repo` - 访问公开仓库
8. 点击 **Generate token**
9. **复制 token**（只显示一次！）

### 3.2 在服务器上配置 Git

```bash
# 配置 Git 用户名
git config --global user.name "Your Name"
git config --global user.email "your_email@example.com"

# 克隆私有仓库（使用 token）
cd ~
mkdir -p iot-hotel-system
cd iot-hotel-system

# 使用 HTTPS + token
git clone https://your-username:YOUR_TOKEN@github.com/choisaaaaa/IoT_Smart_Hotel_System.git

# 或使用环境变量
export GITHUB_TOKEN="YOUR_TOKEN"
git clone https://x-access-token:${GITHUB_TOKEN}@github.com/choisaaaaa/IoT_Smart_Hotel_System.git
```

### 3.3 配置 Git 凭据管理（可选）

```bash
# 配置 Git 凭据缓存
git config --global credential.helper cache

# 或使用存储
git config --global credential.helper store

# 第一次克隆时会提示输入密码，输入 token 即可
git clone https://github.com/choisaaaaa/IoT_Smart_Hotel_System.git
```

---

## 4. 方案三：使用 GitHub CLI

### 4.1 安装 GitHub CLI

```bash
# 在服务器上安装 GitHub CLI
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update
sudo apt install -y gh
```

### 4.2 登录 GitHub

```bash
# 登录 GitHub
gh auth login

# 按提示操作：
# 1. Choose a default host: github.com
# 2. Choose a default API protocol: HTTPS
# 3. Authenticate Git: Yes
# 4. Choose an authentication method: Paste an authentication token
# 5. Paste your authentication token
```

### 4.3 克隆私有仓库

```bash
# 克隆私有仓库
cd ~
mkdir -p iot-hotel-system
cd iot-hotel-system

# 使用 gh 克隆
gh repo clone choisaaaaa/IoT_Smart_Hotel_System.git

# 或使用 git
git clone https://github.com/choisaaaaa/IoT_Smart_Hotel_System.git
```

---

## 5. 常见问题

### 5.1 SSH 连接失败

**问题**：`Permission denied (publickey)`

**解决方案**：

```bash
# 检查 SSH 密钥是否存在
ls -la ~/.ssh

# 检查 SSH 配置
cat ~/.ssh/config

# 测试 SSH 连接（详细模式）
ssh -vT github.com

# 检查 GitHub 已添加的密钥
gh auth status
```

### 5.2 Git 克隆失败

**问题**：`Repository not found`

**解决方案**：

```bash
# 检查仓库地址
git remote -v

# 重新添加远程仓库
git remote add origin git@github.com:choisaaaaa/IoT_Smart_Hotel_System.git

# 或使用 HTTPS + token
git remote set-url origin https://your-username:YOUR_TOKEN@github.com/choisaaaaa/IoT_Smart_Hotel_System.git
```

### 5.3 Token 过期

**问题**：`401 Unauthorized`

**解决方案**：

```bash
# 生成新的 token（参考 3.1 节）

# 更新 Git 凭据
git credential-cache exit
git clone https://your-username:NEW_TOKEN@github.com/choisaaaaa/IoT_Smart_Hotel_System.git

# 或更新环境变量
export GITHUB_TOKEN="NEW_TOKEN"
```

### 5.4 权限不足

**问题**：`Permission denied` 或 `403 Forbidden`

**解决方案**：

```bash
# 检查 token 权限
# 确保 token 有 repo 权限

# 检查仓库访问权限
# 确保 GitHub 账号有仓库访问权限

# 检查 SSH 密钥是否添加到 GitHub
gh auth status
```

### 5.5 二步验证（MFA）问题

**问题**：使用密码克隆失败

**解决方案**：

```bash
# 必须使用 Personal Access Token
# 不能使用账户密码

# 生成 token（参考 3.1 节）
# 使用 token 克隆仓库
git clone https://your-username:TOKEN@github.com/choisaaaaa/IoT_Smart_Hotel_System.git
```

---

## 📋 推荐部署流程

### 使用 SSH 密钥部署（推荐）

```bash
# 1. 在本地生成 SSH 密钥
ssh-keygen -t ed25519 -C "iot-hotel-server"

# 2. 添加公钥到 GitHub
cat ~/.ssh/id_ed25519.pub
# 复制内容到 GitHub Settings → SSH and GPG keys

# 3. 在服务器上配置 SSH
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# 4. 从本地复制私钥到服务器
# 方法 1: 使用 ssh-copy-id
ssh-copy-id -i ~/.ssh/id_ed25519 root@8.134.166.69

# 方法 2: 手动复制
# 在服务器上创建 authorized_keys
echo "你的公钥内容" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

# 5. 在服务器上配置 SSH config
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

```bash
# 6. 测试连接
ssh -T github.com

# 7. 克隆仓库
cd ~
mkdir -p iot-hotel-system
cd iot-hotel-system
git clone git@github.com:choisaaaaa/IoT_Smart_Hotel_System.git
```

---

## 🔐 安全建议

1. **使用 SSH 密钥而非 token**
   - SSH 密钥更安全
   - 不需要频繁更新

2. **限制 token 权限**
   - 只授予必要的权限
   - 设置合理的过期时间

3. **保护私钥**
   - 不要将私钥提交到仓库
   - 使用强密码保护私钥

4. **定期轮换密钥**
   - 每 90 天更换一次 SSH 密钥
   - 每 30 天更换一次 token

5. **使用部署密钥（可选）**
   - 为每个服务器生成独立的部署密钥
   - 限制密钥只能访问特定仓库

---

## 📚 参考资料

- [GitHub SSH 密钥文档](https://docs.github.com/zh/authentication/connecting-to-github-with-ssh)
- [GitHub Personal Access Token 文档](https://docs.github.com/zh/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens)
- [GitHub CLI 文档](https://cli.github.com/manual/)
- [Git 凭据管理](https://git-scm.com/docs/gitcredentials)

---

**最后更新**: 2026-04-07
