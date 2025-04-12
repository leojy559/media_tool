#!/bin/bash

CONFIG_FILE="$HOME/.media_tool_config"
DEFAULT_SCREEN_COUNT=5
DEFAULT_RESOLUTION="1920x1080"
DEFAULT_BBCODE_OUTPUT=false
SELECTED_DIR=""

# 加载配置
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
    else
        SCREEN_COUNT=$DEFAULT_SCREEN_COUNT
        SCREEN_RESOLUTION=$DEFAULT_RESOLUTION
        BBCODE_OUTPUT=$DEFAULT_BBCODE_OUTPUT
    fi
}

# 保存配置
save_config() {
    cat > "$CONFIG_FILE" <<EOF
DOWNLOAD_DIR="$DOWNLOAD_DIR"
SCREEN_COUNT=$SCREEN_COUNT
SCREEN_RESOLUTION="$SCREEN_RESOLUTION"
BBCODE_OUTPUT=$BBCODE_OUTPUT
EOF
}

# 安装依赖
install_dependencies() {
    echo -e "\n[+] 检查并安装必要组件..."
    sudo apt update -qq
    sudo apt install -y mediainfo p7zip-full git curl jq mono-complete pipx python3-venv

    export PATH="$PATH:$HOME/.local/bin:/root/.local/bin"
    pipx ensurepath >/dev/null 2>&1

    # 安装 bdinfo
    if [[ ! -f /usr/local/bin/bdinfo ]]; then
        echo "[+] 下载 bdinfo..."
        sudo wget -q https://raw.githubusercontent.com/akina-up/seedbox-info/master/script/bdinfo -O /usr/local/bin/bdinfo
    fi
    sudo chmod +x /usr/local/bin/bdinfo

    # 安装 jietu
    if [[ ! -f /usr/local/bin/jietu ]]; then
        echo "[+] 下载 jietu..."
        sudo wget -q https://raw.githubusercontent.com/akina-up/seedbox-info/master/script/jietu -O /usr/local/bin/jietu
    fi
    sudo chmod +x /usr/local/bin/jietu

    # 给当前脚本赋予执行权限
    chmod +x "$0"
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
    select MOVIE_DIR in "${MOVIE_DIRS[@]}" "取消"; do
        if [[ "$REPLY" -le "${#MOVIE_DIRS[@]}" && "$REPLY" -gt 0 ]]; then
            SELECTED_DIR="$MOVIE_DIR"
            echo -e "✅ 已选择目录：$SELECTED_DIR"
            break
        elif [[ "$REPLY" -eq $((${#MOVIE_DIRS[@]} + 1)) ]]; then
            echo "已取消选择。"
            break
        else
            echo "无效选择，请重新输入。"
        fi
    done
}

# 修改截图参数
change_screenshot_settings() {
    echo -e "\n当前截图数量：$SCREEN_COUNT，分辨率：$SCREEN_RESOLUTION，BBCode 格式：$BBCODE_OUTPUT"
    read -rp "请输入新的截图数量（回车跳过）: " new_count
    read -rp "请输入新的截图分辨率（如 1920x1080，回车跳过）: " new_resolution
    read -rp "是否输出 BBCode 格式？(true/false，回车跳过，当前为 $BBCODE_OUTPUT): " new_bbcode

    [[ -n "$new_count" ]] && SCREEN_COUNT="$new_count"
    [[ -n "$new_resolution" ]] && SCREEN_RESOLUTION="$new_resolution"
    if [[ "$new_bbcode" == "true" || "$new_bbcode" == "false" ]]; then
        BBCODE_OUTPUT="$new_bbcode"
    fi

    save_config
    echo -e "✅ 已更新截图参数：$SCREEN_COUNT 张，分辨率 $SCREEN_RESOLUTION，BBCode 输出：$BBCODE_OUTPUT"
}

# 获取 mediainfo
run_mediainfo() {
    [[ -z "$SELECTED_DIR" ]] && choose_movie_dir
    echo -e "\n[+] 获取 mediainfo..."
    mediainfo "$SELECTED_DIR"
}

# 获取 bdinfo（使用 --main 自动选择）
run_bdinfo() {
    [[ -z "$SELECTED_DIR" ]] && choose_movie_dir
    echo -e "\n[+] 获取 bdinfo..."
    /usr/local/bin/bdinfo --main "$SELECTED_DIR"
}

# 获取截图并上传
run_screenshots() {
    [[ -z "$SELECTED_DIR" ]] && choose_movie_dir

    echo -e "\n[+] 正在截图并上传..."
    video_file=$(find "$SELECTED_DIR" -type f \( -iname "*.mkv" -o -iname "*.mp4" -o -iname "*.avi" \) | head -n 1)
    if [[ -z "$video_file" ]]; then
        echo "❌ 未找到视频文件。"
        return
    fi

    if [[ "$BBCODE_OUTPUT" == "true" ]]; then
        /usr/local/bin/jietu --file "$video_file" --count "$SCREEN_COUNT" --size "$SCREEN_RESOLUTION" --bbcode
    else
        /usr/local/bin/jietu --file "$video_file" --count "$SCREEN_COUNT" --size "$SCREEN_RESOLUTION"
    fi
}

# 主菜单
main_menu() {
    while true; do
        echo -e "\n====== Media Tool 主菜单 ======"
        if [[ -n "$SELECTED_DIR" ]]; then
            echo "1. 重新选择影视目录（当前：$(basename "$SELECTED_DIR")）"
        else
            echo "1. 选择影视目录（当前未选择）"
        fi
        echo "2. 获取 mediainfo"
        echo "3. 获取 bdinfo"
        echo "4. 获取截图上传链接"
        echo "5. 修改截图参数"
        echo "0. 退出"
        read -rp "请选择操作项 [0-5]: " choice

        case $choice in
            1) choose_movie_dir ;;
            2) run_mediainfo ;;
            3) run_bdinfo ;;
            4) run_screenshots ;;
            5) change_screenshot_settings ;;
            0) echo "退出脚本。"; exit 0 ;;
            *) echo "无效选择，请重新输入。" ;;
        esac
    done
}

# 执行流程
load_config
install_dependencies
setup_download_dir
main_menu
