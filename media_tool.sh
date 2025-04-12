#!/bin/bash
set -e

CONFIG_FILE="$HOME/.media_tool_config"
SCRIPT_DIR="$HOME/scripts"
UPLOAD_DIR="$HOME/log/screenshots"
JIETU="$SCRIPT_DIR/jietu"
IMGBOX="$SCRIPT_DIR/imgbox"
BDINFO="/usr/local/bin/bdinfo"

# 检查并安装 imgbox-cli
function install_imgbox_cli() {
    echo -e "\n[+] 安装 imgbox-cli..."
    sudo apt update
    sudo apt install -y python3-pip

    # 尝试直接安装 imgbox-cli
    if ! pip3 install imgbox-cli; then
        echo -e "\n[!] 安装失败，尝试使用 pipx 安装..."
        sudo apt install -y pipx
        pipx install imgbox-cli
    fi

    echo -e "\n✅ imgbox-cli 安装完成。"
}

# 检查并安装必要组件
function check_and_install() {
    echo -e "\n[+] 检查并安装必要组件..."

    missing=0
    for cmd in mediainfo ffmpeg mono git 7z curl jq; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            echo "[!] 缺少命令：$cmd"
            missing=1
        fi
    done

    if [[ $missing -eq 1 ]]; then
        echo -e "\n[+] 安装缺失依赖..."
        sudo apt update
        sudo apt install -y mediainfo ffmpeg mono-complete git p7zip-full curl jq
    fi

    install_imgbox_cli  # 安装 imgbox-cli

    mkdir -p "$SCRIPT_DIR" "$UPLOAD_DIR"

    if [[ ! -f "$JIETU" ]]; then
        echo -e "\n[+] 下载 jietu 脚本..."
        wget -q https://raw.githubusercontent.com/akina-up/seedbox-info/master/script/jietu -O "$JIETU"
        chmod +x "$JIETU"
    fi

    if [[ ! -f "$BDINFO" ]]; then
        echo -e "\n[+] 下载 bdinfo 脚本..."
        sudo wget -q https://raw.githubusercontent.com/akina-up/seedbox-info/master/script/bdinfo -O "$BDINFO"
        sudo chmod +x "$BDINFO"
    fi

    echo -e "\n✅ 依赖检查完成，必要工具已就绪。"
}

# 获取用户配置
function load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
    else
        echo -e "\n📥 首次使用，请输入 qBittorrent 的下载目录路径："
        read -rp "下载目录 (示例: /home/user/Downloads/Movies): " ROOT_DIR
        echo "ROOT_DIR=\"$ROOT_DIR\"" > "$CONFIG_FILE"
    fi
}

function select_movie() {
    echo -e "\n📁 请选择你需要处理的影视目录："
    local i=1
    for dir in "$ROOT_DIR"/*/; do
        echo "$i) $(basename "$dir")"
        MOVIES[i]="$dir"
        ((i++))
    done

    read -p "#? " choice
    MOVIE_DIR="${MOVIES[$choice]}"
    [[ -z "$MOVIE_DIR" ]] && echo "❌ 无效选择。" && exit 1
    echo "✅ 你选择了：$MOVIE_DIR"

    echo -e "\n📷 截图参数配置"
    read -p "请输入截图张数 (默认 5): " shot_count
    SHOT_COUNT=${shot_count:-5}

    read -p "请输入截图分辨率 (默认 1920x1080): " shot_size
    SHOT_SIZE=${shot_size:-1920x1080}
}

function choose_action() {
    while true; do
        echo -e "\n🔧 请选择你需要的信息："
        echo "1) 获取 mediainfo"
        echo "2) 执行 bdinfo"
        echo "3) 获取截图并上传链接"
        echo "4) 修改截图参数"
        echo "0) 退出"
        read -p "#? " opt

        case $opt in
            1)
                echo -e "\n[+] 获取 mediainfo..."
                for file in "$MOVIE_DIR"/*.{mkv,mp4,ts,avi}; do
                    [[ -f "$file" ]] && echo -e "\n🎬 文件：$(basename "$file")\n" && mediainfo "$file"
                done
                ;;
            2)
                echo -e "\n[+] 执行 bdinfo..."
                bdinfo "$MOVIE_DIR"
                ;;
            3)
                echo -e "\n[+] 开始截图 ($SHOT_COUNT 张，$SHOT_SIZE 分辨率)..."
                COUNT=$SHOT_COUNT SIZE=$SHOT_SIZE bash "$JIETU" "$MOVIE_DIR"

                echo -e "\n[+] 截图上传结果："
                grep -Eo 'https?://[^ ]+' "$UPLOAD_DIR"/*.txt | tail -n $SHOT_COUNT
                ;;
            4)
                echo -e "\n📷 修改截图参数:"
                read -p "请输入截图张数 (当前 $SHOT_COUNT): " shot_count
                SHOT_COUNT=${shot_count:-$SHOT_COUNT}
                read -p "请输入截图分辨率 (当前 $SHOT_SIZE): " shot_size
                SHOT_SIZE=${shot_size:-$SHOT_SIZE}
                echo -e "\n[+] 截图参数已更新: $SHOT_COUNT 张，$SHOT_SIZE 分辨率"
                ;;
            0)
                echo "👋 再见！"
                break
                ;;
            *)
                echo "❌ 无效选项。"
                ;;
        esac
    done
}

function main() {
    check_and_install
    load_config
    select_movie
    choose_action
}

main
