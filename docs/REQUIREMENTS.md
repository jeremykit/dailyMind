# YouTube 频道音频提取系统

## 项目概述

自动监控指定 YouTube 频道，提取新视频音频（MP3），存储到 Cloudflare R2。

## 目标频道

- 频道：`@summit24-138`
- 链接：https://www.youtube.com/@summit24-138/videos
- 视频特征：每日更新，时长约 5 分钟

---

## 技术架构

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  GitHub Actions │────▶│    yt-dlp       │────▶│  Cloudflare R2  │
│  (每小时触发)    │     │  (提取音频)      │     │  (存储 MP3)     │
└─────────────────┘     └─────────────────┘     └─────────────────┘
```

### 组件说明

| 组件 | 作用 |
|------|------|
| GitHub Actions | 定时任务调度器，每小时运行 |
| yt-dlp | 开源工具，从 YouTube 提取音频 |
| rclone | 文件同步工具，上传到 R2 |
| Cloudflare R2 | 对象存储，保存 MP3 文件和索引 |

---

## 存储结构

```
jiamingzh/
  └── daily/
      ├── 2024-12-29_视频标题.mp3    # 日期_标题.mp3
      ├── 2024-12-28_另一个标题.mp3
      └── index.json                 # 元数据索引
```

### index.json 格式

```json
{
  "channel": "@summit24-138",
  "lastUpdated": "2024-12-29T10:00:00Z",
  "videos": [
    {
      "id": "dQw4w9WgXcQ",
      "title": "视频标题",
      "publishedAt": "2024-12-29T08:00:00Z",
      "duration": 312,
      "fileSize": 4823456,
      "addedAt": "2024-12-29T10:15:00Z"
    }
  ]
}
```

---

## 工作流程

```
1. GitHub Actions 定时触发（每小时）
          │
          ▼
2. 从 R2 下载 index.json（获取已处理列表）
          │
          ▼
3. 用 yt-dlp 获取频道最新视频列表
          │
          ▼
4. 对比找出新视频
          │
          ▼
5. 逐个下载音频（MP3 格式，128kbps）
          │
          ▼
6. 上传 MP3 到 R2
          │
          ▼
7. 更新 index.json 并上传
          │
          ▼
8. 完成，等待下次触发
```

---

## 配置需求

### GitHub Secrets（需要你配置）

| Secret 名称 | 说明 |
|-------------|------|
| `R2_ACCOUNT_ID` | Cloudflare 账户 ID |
| `R2_ACCESS_KEY_ID` | R2 API 令牌的 Access Key |
| `R2_SECRET_ACCESS_KEY` | R2 API 令牌的 Secret Key |
| `R2_BUCKET_NAME` | R2 存储桶名称 |

### R2 存储桶设置

1. 在 Cloudflare Dashboard 创建 R2 存储桶
2. 创建 API 令牌（需要 R2 读写权限）
3. 记录 Account ID、Access Key、Secret Key

---

## 文件结构

```
dailyMind/
├── .github/
│   └── workflows/
│       └── youtube-audio.yml    # GitHub Actions 工作流
├── scripts/
│   └── fetch-audio.sh           # 主脚本
├── docs/
│   └── REQUIREMENTS.md          # 本文档
└── README.md
```

---

## 限制与注意事项

1. **GitHub Actions 限制**
   - 免费账户每月 2000 分钟
   - 单次运行最长 6 小时
   - 每小时运行一次，每月约 720 次

2. **R2 免费额度**
   - 10GB 存储
   - 100 万次 A 类请求/月
   - 1000 万次 B 类请求/月
   - 5 分钟音频约 5-8MB，足够存储 1000+ 个

3. **yt-dlp 注意**
   - 依赖 YouTube 网页结构，可能需要定期更新
   - 部分视频可能受地区限制

---

## 待确认事项

请确认以下内容后开始实现：

- [ ] R2 存储桶名称是什么？
- [ ] 存储路径用 `audios/` 还是其他？
- [ ] 音频质量：128kbps 够用吗？还是需要更高？
- [ ] 是否需要保留原始视频标题作为文件名的一部分？

---

## 下一步

确认后我将创建：
1. `.github/workflows/youtube-audio.yml` - Actions 工作流
2. `scripts/fetch-audio.sh` - 核心处理脚本
