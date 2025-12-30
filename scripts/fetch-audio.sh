#!/bin/bash

# YouTube 音频提取脚本
# 从指定频道获取最新视频，提取音频并更新索引

set -e

CHANNEL_URL="https://www.youtube.com/@summit24-138/videos"
INDEX_FILE="./temp/index.json"
EXISTING_FILES="./temp/existing_files.txt"
COOKIES_FILE="./temp/cookies.txt"
OUTPUT_DIR="./output"
MAX_VIDEOS=5  # 每次最多处理的新视频数量

mkdir -p "$OUTPUT_DIR"
mkdir -p ./temp

# 确保 index.json 存在
if [ ! -f "$INDEX_FILE" ]; then
    echo '{"channel":"@summit24-138","lastUpdated":"","videos":[]}' > "$INDEX_FILE"
fi

# 确保 existing_files.txt 存在
if [ ! -f "$EXISTING_FILES" ]; then
    touch "$EXISTING_FILES"
fi

# 构建 yt-dlp 基础参数
YTDLP_ARGS=""

# 检查 cookies 文件是否有效（必须是 Netscape 格式）
if [ -f "$COOKIES_FILE" ] && [ -s "$COOKIES_FILE" ]; then
    # 检查是否是 Netscape 格式（包含 tab 分隔的行）
    if grep -qE '^\.?[a-zA-Z].*\t(TRUE|FALSE)\t' "$COOKIES_FILE" 2>/dev/null; then
        YTDLP_ARGS="--cookies $COOKIES_FILE"
        echo "==> 使用 Netscape 格式 cookies 文件"
    else
        echo "==> cookies 文件不是 Netscape 格式，跳过使用"
    fi
fi

# 添加绕过检测的参数
YTDLP_ARGS="$YTDLP_ARGS --extractor-args youtube:player_client=web_safari,android_music"
YTDLP_ARGS="$YTDLP_ARGS --sleep-interval 2 --max-sleep-interval 5"
YTDLP_ARGS="$YTDLP_ARGS --retries 3"

echo "==> yt-dlp 版本: $(yt-dlp --version)"
echo "==> 获取频道最新视频列表..."

# 获取最新视频列表（最近10个）
yt-dlp $YTDLP_ARGS --flat-playlist --print "%(id)s|%(title)s|%(upload_date)s" \
    --playlist-end 10 \
    "$CHANNEL_URL" > ./temp/video_list.txt 2>&1 || true

if [ ! -s ./temp/video_list.txt ]; then
    echo "未能获取视频列表，退出"
    exit 0
fi

echo "==> 视频列表:"
cat ./temp/video_list.txt

echo "==> 检查新视频..."

# 读取已处理的视频 ID
PROCESSED_IDS=$(cat "$INDEX_FILE" | grep -oP '"id"\s*:\s*"\K[^"]+' || echo "")

NEW_COUNT=0

while IFS='|' read -r VIDEO_ID TITLE UPLOAD_DATE; do
    # 跳过空行
    [ -z "$VIDEO_ID" ] && continue

    # 检查是否已处理
    if echo "$PROCESSED_IDS" | grep -q "$VIDEO_ID"; then
        echo "跳过已处理: $TITLE"
        continue
    fi

    # 限制每次处理数量
    if [ $NEW_COUNT -ge $MAX_VIDEOS ]; then
        echo "已达到单次处理上限 ($MAX_VIDEOS)，剩余视频下次处理"
        break
    fi

    echo "==> 处理新视频: $TITLE"

    # 格式化日期
    if [ -n "$UPLOAD_DATE" ] && [ "$UPLOAD_DATE" != "NA" ]; then
        FORMATTED_DATE=$(echo "$UPLOAD_DATE" | sed 's/\(....\)\(..\)\(..\)/\1-\2-\3/')
    else
        FORMATTED_DATE=$(date +%Y-%m-%d)
    fi

    # 清理文件名（移除特殊字符）
    SAFE_TITLE=$(echo "$TITLE" | sed 's/[\/\\:*?"<>|]/_/g' | sed 's/  */ /g' | head -c 100)
    FILENAME="${FORMATTED_DATE}_${SAFE_TITLE}.mp3"

    echo "文件名: $FILENAME"

    # 检查文件是否已存在于 R2
    if grep -qF "$FILENAME" "$EXISTING_FILES" 2>/dev/null; then
        echo "文件已存在于 R2，跳过: $FILENAME"
        continue
    fi

    # 下载音频（优先使用格式 140 m4a，然后转换为 mp3）
    yt-dlp $YTDLP_ARGS \
        -f "140/bestaudio[ext=m4a]/bestaudio" \
        -x --audio-format mp3 --audio-quality 128K \
        --output "$OUTPUT_DIR/$FILENAME" \
        "https://www.youtube.com/watch?v=$VIDEO_ID" || {
        echo "下载失败: $VIDEO_ID"
        continue
    }

    # 获取文件大小
    if [ -f "$OUTPUT_DIR/$FILENAME" ]; then
        FILE_SIZE=$(stat -c%s "$OUTPUT_DIR/$FILENAME" 2>/dev/null || echo "0")
    else
        FILE_SIZE=0
    fi

    # 更新 index.json
    CURRENT_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # 使用 jq 更新 JSON
    if command -v jq &> /dev/null; then
        # 创建新的视频条目
        NEW_ENTRY=$(jq -n \
            --arg id "$VIDEO_ID" \
            --arg title "$TITLE" \
            --arg filename "$FILENAME" \
            --arg published "$FORMATTED_DATE" \
            --arg added "$CURRENT_TIME" \
            --argjson size "$FILE_SIZE" \
            '{id: $id, title: $title, filename: $filename, publishedAt: $published, addedAt: $added, fileSize: $size}')

        # 添加到 index.json
        jq --argjson entry "$NEW_ENTRY" \
           --arg time "$CURRENT_TIME" \
           '.lastUpdated = $time | .videos = [$entry] + .videos' \
           "$INDEX_FILE" > ./temp/index_new.json
        mv ./temp/index_new.json "$INDEX_FILE"
    else
        echo "警告: jq 未安装，跳过索引更新"
    fi

    echo "==> 完成: $FILENAME"
    NEW_COUNT=$((NEW_COUNT + 1))

done < ./temp/video_list.txt

echo "==> 处理完成，新增 $NEW_COUNT 个视频"
