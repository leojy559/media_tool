#!/bin/bash

# 默认截图参数
SHOT_COUNT=5
SHOT_RESOLUTION="1920x1080"

# 用户首次设置的下载目录会保存到这个文件中
CONFIG_FILE="$HOME/.media_tool_config"

# 检查并安装依赖
check_dependencies() {
    echo "[+] 检查并安装必要组件：git, curl, jq, p7zip-full, mediainfo, ffmpeg, pipx"
    sudo apt update >/dev/null
    sudo apt install -y git curl jq p7zip-full mediainfo ffmpeg python3-pip >/dev/null

    if ! command -v pipx &>/dev/null; then
        echo "[+] 安装 pipx..."
        sudo apt install pipx -y >/dev/null
        pipx ensurepath
    fi

    if ! command -v imgbox &>/dev/null; then
        echo "[+] 安装 imgbox-cli..."
        pipx install imgbox-cli
    fi
}

# 选择影视目录
choose_media_dir() {
    echo "📁 当前未设置影视目录，请输入你的 qBittorrent 下载目录路径："
    read -rp "> " MEDIA_DIR
    echo "$MEDIA_DIR" > "$CONFIG_FILE"
}

# 显示目录列表供用户选择
select_movie_folder() {
    MOVIES=("$(ls -1 "$MEDIA_DIR")")
    while true; do
        echo -e "\n🎬 读取影视目录：$MEDIA_DIR"
        i=1
        for movie in "$MEDIA_DIR"/*; do
            [ -d "$movie" ] && echo "$i. $(basename "$movie")" && MOVIE_MAP[$i]="$movie" && ((i++))
        done
        echo "$i. 返回主菜单"
        read -rp "> " SELECTED
        if [[ $SELECTED -ge 1 && $SELECTED -lt $i ]]; then
            CURRENT_DIR="${MOVIE_MAP[$SELECTED]}"
            break
        elif [[ $SELECTED -eq $i ]]; then
            CURRENT_DIR=""
            break
        else
            echo "无效选择，请重试。"
        fi
    done
}

# 主菜单
main_menu() {
    while true; do
        echo -e "\n📋 主菜单："
        echo "1. 获取 mediainfo"
        echo "2. 获取 bdinfo"
        echo "3. 获取截图链接"
        echo "4. 修改截图参数（当前数量：$SHOT_COUNT，分辨率：$SHOT_RESOLUTION）"
        echo "0. 退出"
        read -rp "> " ACTION

        case $ACTION in
            1)
                echo "\n📦 获取 mediainfo..."
                mediainfo "$CURRENT_DIR"
                ;;
            2)
                echo "\n📦 获取 bdinfo..."
                chmod +x /usr/local/bin/bdinfo
                /usr/local/bin/bdinfo "$CURRENT_DIR" > bdinfo.txt
                cat bdinfo.txt
                ;;
            3)
                echo "\n📸 开始生成截图（共 $SHOT_COUNT 张，分辨率 $SHOT_RESOLUTION）..."
                FILE=$(find "$CURRENT_DIR" -type f -name '*.mkv' -o -name '*.mp4' | head -n 1)
                ffmpeg -hide_banner -loglevel error -i "$FILE" -vf "fps=1/60,scale=$SHOT_RESOLUTION" -vframes "$SHOT_COUNT" "$CURRENT_DIR/snap_%03d.jpg"
                LINKS=()
                for img in "$CURRENT_DIR"/snap_*.jpg; do
                    LINK=$(imgbox upload "$img")
                    LINKS+=("$LINK")
                done
                printf "%s\n" "${LINKS[@]}" | tee screenshot_links.txt
                ;;
            4)
                echo "🛠 修改截图参数"
                read -rp "请输入截图数量（当前为 $SHOT_COUNT）：" NEW_COUNT
                read -rp "请输入截图分辨率（当前为 $SHOT_RESOLUTION）：" NEW_RES
                SHOT_COUNT=${NEW_COUNT:-$SHOT_COUNT}
                SHOT_RESOLUTION=${NEW_RES:-$SHOT_RESOLUTION}
                echo "✅ 参数更新成功"
                ;;
            0)
                echo "👋 再见！"
                exit 0
                ;;
            *)
                echo "无效选择，请重试。"
                ;;
        esac
    done
}

# 入口
check_dependencies
if [[ ! -f "$CONFIG_FILE" ]]; then
    choose_media_dir
fi
MEDIA_DIR=$(cat "$CONFIG_FILE")

while true; do
    echo -e "\n📂 一级菜单："
    echo "1. 选择影视目录"
    if [[ -n "$CURRENT_DIR" ]]; then
        echo "2. 获取 mediainfo"
        echo "3. 获取 bdinfo"
        echo "4. 获取截图链接"
        echo "5. 修改截图参数（当前数量：$SHOT_COUNT，分辨率：$SHOT_RESOLUTION）"
        echo "0. 退出"
    else
        echo "0. 退出"
    fi
    read -rp "> " MAIN_CHOICE

    if [[ "$MAIN_CHOICE" == "1" ]]; then
        select_movie_folder
    elif [[ "$MAIN_CHOICE" == "0" ]]; then
        echo "👋 再见！"
        exit 0
    elif [[ -n "$CURRENT_DIR" ]]; then
        case $MAIN_CHOICE in
            2) ACTION=1 ; main_menu ;;
            3) ACTION=2 ; main_menu ;;
            4) ACTION=3 ; main_menu ;;
            5) ACTION=4 ; main_menu ;;
            *) echo "无效选择。" ;;
        esac
    else
        echo "⚠️  请先选择影视目录！"
    fi

done
