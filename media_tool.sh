#!/bin/bash

# 获取当前登录用户名
LOGIN_USER=$(logname)
DEFAULT_PATH="/home/$LOGIN_USER/qbittorrent/Downloads"
CONFIG_FILE="$HOME/.media_tool_config"
PTPIMG_KEY_FILE="$HOME/.ptpimg_api"

# 加载配置
[ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"
SCREEN_COUNT=${SCREEN_COUNT:-5}

# 保存配置
function save_config() {
    echo "DOWNLOAD_PATH=\"$DOWNLOAD_PATH\"" > "$CONFIG_FILE"
    echo "SCREEN_COUNT=\"$SCREEN_COUNT\"" >> "$CONFIG_FILE"
}

# 设置下载目录
function set_download_dir() {
    echo -ne "请输入 qBittorrent 的下载目录路径（默认: $DEFAULT_PATH）："
    read -e input_path
    DOWNLOAD_PATH=${input_path:-$DEFAULT_PATH}
    save_config
    echo -e "\n使用的下载目录为: $DOWNLOAD_PATH"
}

# 安装依赖
function install_dependencies() {
    echo -e "\n[+] 正在安装依赖..."

    # jietu
    if ! command -v jietu &>/dev/null; then
        wget -q https://raw.githubusercontent.com/akina-up/seedbox-info/master/script/jietu -O /usr/local/bin/jietu && chmod +x /usr/local/bin/jietu
    fi

    # nconvert
    if ! command -v nconvert &>/dev/null; then
        wget https://download.xnview.com/NConvert-linux64.tgz && tar -xvzf NConvert-linux64.tgz --strip-components=1 -C /tmp && mv /tmp/nconvert /usr/local/bin/ && chmod +x /usr/local/bin/nconvert
        rm -f NConvert-linux64.tgz
    fi

    # imgbox-cli（默认安装）
    if ! command -v imgbox &>/dev/null; then
        apt install -y python3-pip
        pip install imgbox-cli --break-system-packages
    fi

    # mediainfo
    if ! command -v mediainfo &>/dev/null; then
        apt install -y mediainfo
    fi

    # bdinfo
    if ! command -v bdinfo &>/dev/null; then
        apt install -y mono-complete git
        wget -q https://raw.githubusercontent.com/akina-up/seedbox-info/master/script/bdinfo -O /usr/local/bin/bdinfo && chmod +x /usr/local/bin/bdinfo
    fi

    echo "[+] 所有依赖安装完成。"
}

# 列出文件夹和文件
function list_folders() {
    echo -e "\n[+] 获取下载目录下的文件夹和文件..."

    # 获取下载目录下的所有文件和文件夹
    IFS=$'\n' read -rd '' -a items <<< "$(find "$DOWNLOAD_PATH" -mindepth 1 -maxdepth 1 -printf '%P\n' 2>/dev/null | sort)"
    
    if [ ${#items[@]} -eq 0 ]; then
        echo "没有找到任何文件或文件夹。"
        echo -ne "是否要修改下载目录？(y/n): "
        read -r answer
        if [[ "$answer" == [Yy] ]]; then
            set_download_dir
            list_folders
        else
            echo "退出脚本。"
            exit 1
        fi
        return
    fi

    echo -e "[+] 选择一个文件夹或文件进行操作:"
    for item in "${items[@]}"; do
        # 判断是文件夹还是文件
        if [ -d "$DOWNLOAD_PATH/$item" ]; then
            # 如果是文件夹，检查是否包含媒体文件
            media_files=$(find "$DOWNLOAD_PATH/$item" -maxdepth 1 -type f \( -iname "*.mkv" -o -iname "*.mp4" -o -iname "*.m2ts" -o -iname "*.iso" \))
            if [ -n "$media_files" ]; then
                echo "$item"
            fi
        elif [ -f "$DOWNLOAD_PATH/$item" ]; then
            # 如果是文件，检查是否是媒体文件
            if [[ "$item" =~ \.(mkv|mp4|m2ts|iso)$ ]]; then
                # 隐藏文件后缀
                file_name_without_extension="${item%.*}"
                echo "$file_name_without_extension"
            fi
        fi
    done

    echo "0. 返回"

    echo -ne "\n请选择一个文件夹或文件进行操作 (输入编号): "
    read -r folder_choice

    if [ "$folder_choice" == "0" ]; then
        return
    fi

    folder_index=$((folder_choice-1))
    if [ -z "${items[$folder_index]}" ]; then
        echo "无效选择。"
        list_folders
        return
    fi

    SELECTED_ITEM="$DOWNLOAD_PATH/${items[$folder_index]}"
    echo -e "\n你选择了: $SELECTED_ITEM"
    action_menu "$SELECTED_ITEM"
}

# 卸载工具
function uninstall_tools() {
    echo -e "\n选择要卸载的工具："
    echo "1. 卸载 jietu"
    echo "2. 卸载 nconvert"
    echo "3. 卸载 imgbox-cli"
    echo "4. 卸载 mediainfo"
    echo "5. 卸载 bdinfo"
    echo "0. 返回"
    echo -ne "请输入选择: "
    read -r uninstall_choice

    case $uninstall_choice in
        1) rm -f /usr/local/bin/jietu && echo "已卸载 jietu" ;;
        2) rm -f /usr/local/bin/nconvert && echo "已卸载 nconvert" ;;
        3) pip uninstall -y imgbox-cli || pipx uninstall imgbox-cli && echo "已卸载 imgbox-cli" ;;
        4) apt remove -y mediainfo && echo "已卸载 mediainfo" ;;
        5) rm -f /usr/local/bin/bdinfo && echo "已卸载 bdinfo" ;;
        0) return ;;
        *) echo "无效选择。" ;;
    esac
}

# 主菜单逻辑
function action_menu() {
    local target_folder="$1"
    while true; do
        echo -e "\n====== Media Tool 主菜单 ======"
        echo -e "⚠️ 注意剧集为 mediainfo，原盘为 bdinfo"
        echo "1. 获取 mediainfo 信息"
        echo "2. 获取 bdinfo 信息"
        echo "3. 获取截图上传链接 (截图 + 压缩 + 上传图床)"
        echo "4. 修改截图数量（当前数量：${SCREEN_COUNT}）"
        echo "5. 重新选择影视目录"
        echo "6. 设置下载目录"
        echo "7. 卸载工具（jietu nconvert imgbox mediainfo bdinfo）"
        echo "0. 退出"

        echo -ne "\n选择操作 (输入编号): "
        read -r action_choice

        case $action_choice in
            1)
                echo -e "\n[+] 获取 mediainfo 信息..."
                mediainfo "$target_folder"
                ;;
            2)
                if [ ! -d "$target_folder/BDMV" ]; then
                    echo -e "\n⚠️ 警告: 该目录不是一个有效的 bdinfo 原盘目录（缺少 BDMV 文件夹）"
                else
                    echo -e "\n[+] 获取 bdinfo 信息..."
                    bdinfo "$target_folder"
                fi
                ;;
            3)
                echo -ne "是否提供 ptpimg API Key？(n 表示不使用): "
                read -r key_input
                if [ "$key_input" != "n" ] && [ -n "$key_input" ]; then
                    echo "$key_input" > "$PTPIMG_KEY_FILE"
                    pip install ptpimg-uploader --break-system-packages
                    export PTPIMG_API_KEY="$key_input"
                    echo "[+] ptpimg 设置成功，后续默认使用"
                fi

                jietu "$target_folder"
                ;;
            4)
                echo -ne "请输入新的截图数量（当前: $SCREEN_COUNT）: "
                read -r new_count
                if [[ "$new_count" =~ ^[0-9]+$ ]]; then
                    SCREEN_COUNT="$new_count"
                    save_config
                    sed -i "s/^pics=.*/pics=$SCREEN_COUNT/" /usr/local/bin/jietu
                    echo "[+] 截图数量已更新为 $SCREEN_COUNT"
                else
                    echo "输入无效。"
                fi
                ;;
            5)
                list_folders
                return
                ;;
            6)
                set_download_dir
                list_folders
                return
                ;;
            7)
                uninstall_tools
                ;;
            0)
                echo "退出程序。"
                exit 0
                ;;
            *) echo "无效选择。" ;;
        esac
    done
}

# 启动
install_dependencies
[ -z "$DOWNLOAD_PATH" ] && set_download_dir
save_config
list_folders
