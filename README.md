# DailyMind

自动从 YouTube 频道 [@summit24-138](https://www.youtube.com/@summit24-138/videos) 提取音频，存储到 Cloudflare R2。

## 工作原理

- GitHub Actions 每小时检查频道新视频
- 使用 yt-dlp + Deno 提取音频为 MP3 (128kbps)
- 上传到 Cloudflare R2 存储桶

## 配置

在 GitHub 仓库设置中添加以下 Secrets：

| Secret | 说明 |
|--------|------|
| `R2_ACCOUNT_ID` | Cloudflare 账户 ID |
| `R2_ACCESS_KEY_ID` | R2 API Access Key |
| `R2_SECRET_ACCESS_KEY` | R2 API Secret Key |
| `R2_BUCKET_NAME` | 存储桶名称 (`jiamingzh`) |
| `YOUTUBE_COOKIES` | YouTube cookies 字符串（见下方说明） |

### 获取 R2 API 凭证

1. 登录 [Cloudflare Dashboard](https://dash.cloudflare.com/)
2. 左侧菜单选择 **R2 对象存储**
3. 点击右上角 **管理 R2 API 令牌**
4. 点击 **创建 API 令牌**
5. 设置：
   - 名称：`dailymind` （或任意名称）
   - 权限：选择 **对象读和写**
   - 指定存储桶：选择 `jiamingzh`（或选择"应用到所有存储桶"）
6. 点击 **创建 API 令牌**
7. 复制显示的值：
   - **Access Key ID** → `R2_ACCESS_KEY_ID`
   - **Secret Access Key** → `R2_SECRET_ACCESS_KEY`

**注意**：Secret Access Key 只显示一次，请立即保存！

`R2_ACCOUNT_ID` 可以在 Cloudflare Dashboard 右侧边栏的 **账户 ID** 中找到。

### 获取 YouTube Cookies

1. 安装 Chrome 扩展 [Get cookies.txt LOCALLY](https://chrome.google.com/webstore/detail/get-cookiestxt-locally/cclelndahbckbenkjhflpdbgdldlbecc)
2. 登录 YouTube
3. 打开 YouTube 页面，点击扩展导出 cookies
4. 复制整行内容（格式如 `LOGIN_INFO=xxx; SID=xxx; ...`）
5. 添加到 GitHub Secrets 的 `YOUTUBE_COOKIES`

**注意**：Cookies 可能会过期，如果下载失败需要重新获取。

## 存储结构

```
jiamingzh/
  └── daily/
      ├── 2025-12-29_视频标题.mp3
      ├── index.json
      └── ...
```

## 手动触发

在 GitHub Actions 页面点击 "Run workflow" 可手动触发。
