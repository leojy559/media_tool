#!/bin/bash

CONFIG_FILE="$HOME/.media_tool_config"
DOWNLOAD_DIR=""
SCREENSHOT_COUNT=5
SCREENSHOT_RESOLUTION="1920x1080"
BBCODE_OUTPUT=false

# 载入配置
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
    fi
}

# 保存配置
save_config() {
    cat <<EOF > "$CONFIG_FILE"
DOWNLOAD_DIR="$DOWNLOAD_DIR"
SCREENSHOT_COUNT=$SCREENSHOT_COUNT
SCREENSHOT_RESOLUTION="$SCREENSHOT_RESOLUTION"
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
    echo -e "\n请输入 qBittorrent 的下载目录路径（如 /home/user/qbittorrent/Downloads）："
    read -r DOWNLOAD_DIR
    save_config
}

# 获取 mediainfo
get_mediainfo() {
    echo -e "\n[+] 获取 mediainfo..."
    mediainfo "$DOWNLOAD_DIR"/*
}

# 获取 bdinfo
get_bdinfo() {
    echo -e "\n[+] 获取 bdinfo..."
    bdinfo "$DOWNLOAD_DIR" | tee /tmp/bdinfo_output.txt
}

# 获取截图
get_screenshots() {
    echo -e "\n[+] 上传截图..."
    TEMP_DIR="/tmp/screens_$(date +%s)"
    mkdir -p "$TEMP_DIR"
    jietu "$DOWNLOAD_DIR" "$SCREENSHOT_COUNT" "$SCREENSHOT_RESOLUTION" "$TEMP_DIR"

    for img in "$TEMP_DIR"/*.jpg; do
        if $BBCODE_OUTPUT; then
            echo "[img]$(imgbox upload "$img")[/img]"
        else
            imgbox upload "$img"
        fi
    done
}

# 修改截图参数
modify_screenshot_params() {
    echo -e "\n当前截图数量：$SCREENSHOT_COUNT，分辨率：$SCREENSHOT_RESOLUTION，BBCode 格式：$BBCODE_OUTPUT"
    read -rp "请输入新的截图数量（回车跳过）: " new_count
    [[ -n "$new_count" ]] && SCREENSHOT_COUNT="$new_count"

    read -rp "请输入新的截图分辨率（如 1920x1080，回车跳过）: " new_resolution
    [[ -n "$new_resolution" ]] && SCREENSHOT_RESOLUTION="$new_resolution"

    read -rp "是否输出 BBCode 格式？(true/false，回车跳过，当前为 $BBCODE_OUTPUT): " new_bbcode
    [[ -n "$new_bbcode" ]] && BBCODE_OUTPUT="$new_bbcode"

    save_config
}

# 主菜单
main_menu() {
    while true; do
        echo -e "\n==== Media Tool 主菜单 ===="
        echo "1. 选择影视目录"
        echo "2. 获取 mediainfo"
        echo "3. 获取 bdinfo"
        echo "4. 获取截图链接"
        echo "5. 修改截图参数"
        echo "6. 退出"
        read -rp "请选择操作: " choice

        case $choice in
            1)
                setup_download_dir
                ;;
            2|3|4)
                [[ -z "$DOWNLOAD_DIR" || ! -d "$DOWNLOAD_DIR" ]] && setup_download_dir
                case $choice in
                    2) get_mediainfo ;;
                    3) get_bdinfo ;;
                    4) get_screenshots ;;
                esac
                ;;
            5)
                modify_screenshot_params
                ;;
            6)
                exit 0
                ;;
            *)
                echo "无效选择，请重新输入。"
                ;;
        esac
    done
}

# 初始化并启动
install_dependencies
load_config
main_menu