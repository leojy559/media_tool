#!/bin/bash
set -e

# ========== 可修改配置 ==========
ROOT_DIR="$HOME/Downloads/Movies"
SCRIPT_DIR="$HOME/scripts"
UPLOAD_DIR="$HOME/log/screenshots"
JIETU="$SCRIPT_DIR/jietu"
IMGBOX="$SCRIPT_DIR/imgbox"
BDINFO="/usr/local/bin/bdinfo"

# ========== 安装依赖和工具 ==========
function install_dependencies() {
    echo -e "\n[+] 安装基础依赖..."
    sudo apt update
    sudo apt install -y mediainfo ffmpeg mono-complete git p7zip-full curl jq

    echo -e "\n[+] 创建必要目录..."
    mkdir -p "$SCRIPT_DIR" "$UPLOAD_DIR"

    echo -e "\n[+] 下载 jietu 脚本..."
    wget -q https://raw.githubusercontent.com/akina-up/seedbox-info/master/script/jietu -O "$JIETU"
    chmod +x "$JIETU"

    echo -e "\n[+] 下载 bdinfo 脚本..."
    sudo wget -q https://raw.githubusercontent.com/akina-up/seedbox-info/master/script/bdinfo -O "$BDINFO"
    sudo chmod +x "$BDINFO"

    echo -e "\n[+] 下载 imgbox 上传脚本..."
    wget -q https://raw.githubusercontent.com/akina-up/seedbox-info/master/script/imgbox -O "$IMGBOX"
    chmod +x "$IMGBOX"

    echo -e "\n[+] 配置 jietu 默认使用 imgbox 上传脚本..."
    sed -i "s|^uploader=.*|uploader=$IMGBOX|" "$JIETU"

    echo -e "\n✅ 所有工具安装完成并已配置好 imgbox 图床上传。"
}

# ========== 选择影视目录 ==========
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
}

# ========== 功能选择 ==========
function choose_action() {
    echo -e "\n🔧 请选择你需要的信息："
    echo "1) 获取 mediainfo"
    echo "2) 执行 bdinfo"
    echo "3) 获取截图并上传链接"
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
            echo -e "\n[+] 开始截图..."
            bash "$JIETU" "$MOVIE_DIR"

            echo -e "\n[+] 截图上传结果："
            grep -Eo 'https?://[^ ]+' "$UPLOAD_DIR"/*.txt
            ;;
        *)
            echo "❌ 无效选项。" && exit 1
            ;;
    esac
}

# ========== 主流程 ==========
function main() {
    install_dependencies
    select_movie
    choose_action
}

main