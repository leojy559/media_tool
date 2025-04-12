#!/bin/bash

CONFIG_FILE="$HOME/.media_tool_config"
DEFAULT_SCREEN_COUNT=5
DEFAULT_RESOLUTION="1920x1080"

# 加载配置
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
    else
        SCREEN_COUNT=$DEFAULT_SCREEN_COUNT
        SCREEN_RESOLUTION=$DEFAULT_RESOLUTION
    fi
}

# 保存配置
save_config() {
    cat > "$CONFIG_FILE" <<EOF
DOWNLOAD_DIR="$DOWNLOAD_DIR"
SCREEN_COUNT=$SCREEN_COUNT
SCREEN_RESOLUTION="$SCREEN_RESOLUTION"
EOF
}

# 安装依赖
install_dependencies() {
    echo -e "\n[+] 检查并安装必要组件..."
    sudo apt update
    sudo apt install -y mediainfo p7zip-full git curl jq mono-complete

    # 安装 bdinfo
    if [[ ! -f /usr/local/bin/bdinfo ]]; then
        echo "[+] 下载 bdinfo..."
        sudo wget -q https://raw.githubusercontent.com/akina-up/seedbox-info/master/script/bdinfo -O /usr/local/bin/bdinfo
        sudo chmod +x /usr/local/bin/bdinfo
    fi

    # 安装 pipx
    if ! command -v pipx &> /dev/null; then
        echo "[+] 安装 pipx..."
        sudo apt install -y pipx python3-venv
        python3 -m ensurepip --upgrade
    fi

    # 安装 imgbox-cli
    if ! command -v imgbox &> /dev/null; then
        echo "[+] 安装 imgbox-cli..."
        pipx install imgbox-cli
    fi
}

# 设置下载目录
setup_download_dir() {
    if [[ -z "$DOWNLOAD_DIR" || ! -d "$DOWNLOAD_DIR" ]]; then
        echo -e "\n请输入 qBittorrent 的下载目录路径（如 /home/ikirito/qbittorrent/Downloads）："
        read -r DOWNLOAD_DIR
        save_config
    fi
}

# 选择影视文件夹
choose_movie_dir() {
    MOVIE_DIRS=("$DOWNLOAD_DIR"/*)
    echo -e "\n请选择你要操作的影视文件夹："
    select MOVIE_DIR in "${MOVIE_DIRS[@]}" "返回上层"; do
        if [[ "$REPLY" -le "${#MOVIE_DIRS[@]}" && "$REPLY" -gt 0 ]]; then
            break
        elif [[ "$REPLY" -eq $((${#MOVIE_DIRS[@]} + 1)) ]]; then
            return
        else
            echo "无效选择，请重新输入。"
        fi
    done
}

# 修改截图参数
change_screenshot_settings() {
    echo -e "\n当前截图数量：$SCREEN_COUNT，分辨率：$SCREEN_RESOLUTION"
    read -rp "请输入新的截图数量（回车跳过）: " new_count
    read -rp "请输入新的截图分辨率（如 1920x1080，回车跳过）: " new_resolution
    [[ -n "$new_count" ]] && SCREEN_COUNT="$new_count"
    [[ -n "$new_resolution" ]] && SCREEN_RESOLUTION="$new_resolution"
    save_config
    echo -e "✅ 已更新截图参数：$SCREEN_COUNT 张，分辨率 $SCREEN_RESOLUTION"
}

# 获取 mediainfo
run_mediainfo() {
    echo -e "\n[+] 获取 mediainfo..."
    mediainfo "$MOVIE_DIR"
}

# 获取 bdinfo
run_bdinfo() {
    echo -e "\n[+] 获取 bdinfo..."
    sudo /usr/local/bin/bdinfo "$MOVIE_DIR"
}

# 获取截图并上传
run_screenshots() {
    echo -e "\n[+] 正在截图并上传..."
    video_file=$(find "$MOVIE_DIR" -type f \( -iname "*.mkv" -o -iname "*.mp4" -o -iname "*.avi" \) | head -n 1)
    if [[ -z "$video_file" ]]; then
        echo "未找到视频文件。"
        return
    fi

    shot_dir="/tmp/screens_$(date +%s)"
    mkdir -p "$shot_dir"

    ffmpeg -hide_banner -loglevel error -i "$video_file" -vf "select=not(mod(n\,1000)),scale=$SCREEN_RESOLUTION" -frames:v "$SCREEN_COUNT" "$shot_dir/screen_%02d.jpg"

    echo -e "\n[+] 上传截图..."
    for img in "$shot_dir"/*.jpg; do
        imgbox upload "$img"
    done
}

# 主菜单
main_menu() {
    while true; do
        echo -e "\n====== Media Tool 主菜单 ======"
        echo "1. 获取 mediainfo"
        echo "2. 获取 bdinfo"
        echo "3. 获取截图并上传链接"
        echo "4. 修改截图参数"
        echo "5. 退出"
        read -rp "请选择操作项 [1-5]: " choice

        case $choice in
            1)
                choose_movie_dir
                run_mediainfo
                ;;
            2)
                choose_movie_dir
                run_bdinfo
                ;;
            3)
                choose_movie_dir
                run_screenshots
                ;;
            4)
                change_screenshot_settings
                ;;
            5)
                echo "退出脚本。"
                exit 0
                ;;
            *)
                echo "无效选择，请重新输入。"
                ;;
        esac
    done
}

# 执行流程
load_config
install_dependencies
setup_download_dir
main_menu
