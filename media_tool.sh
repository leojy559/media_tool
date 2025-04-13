#!/bin/bash

# 获取当前用户名，若是在 root 用户环境下运行则通过 $SUDO_USER 获取
get_username() {
    if [ -n "$SUDO_USER" ]; then
        # 如果是使用 sudo 进入的 root 环境，获取最初的用户
        echo "$SUDO_USER"
    else
        # 否则获取当前用户
        echo "$(whoami)"
    fi
}

# 获取下载目录
get_download_dir() {
    # 默认路径
    default_dir="/home/$(get_username)/qbittorrent/Downloads"

    # 提示用户输入下载目录路径
    echo -e "请输入 qBittorrent 的下载目录路径（默认: $default_dir）："
    read -r DOWNLOAD_DIR

    # 如果用户没有输入路径，则使用默认路径
    if [ -z "$DOWNLOAD_DIR" ]; then
        DOWNLOAD_DIR=$default_dir
    fi

    # 输出下载目录路径
    echo "使用的下载目录为: $DOWNLOAD_DIR"

    # 列出目录中的文件夹
    echo -e "\n[+] 获取下载目录下的文件夹..."
    movie_folders=$(find "$DOWNLOAD_DIR" -mindepth 1 -maxdepth 1 -type d)
    
    if [ -z "$movie_folders" ]; then
        echo "没有找到任何影视文件夹。"
        exit 1
    fi

    echo -e "[+] 选择一个文件夹进行操作:"

    # 给文件夹编号
    i=1
    for folder in $movie_folders; do
        folder_name=$(basename "$folder")
        echo "$i. $folder_name"
        i=$((i+1))
    done

    # 提示用户选择文件夹
    echo -n "请选择一个文件夹进行操作 (输入编号): "
    read -r folder_choice

    selected_folder=$(echo "$movie_folders" | sed -n "${folder_choice}p")
    selected_folder_name=$(basename "$selected_folder")

    if [ -z "$selected_folder" ]; then
        echo "无效的选择。退出。"
        exit 1
    fi

    echo "你选择了文件夹: $selected_folder_name"
    return $selected_folder
}

# 主菜单
main_menu() {
    # 获取下载目录路径
    get_download_dir

    # 在此基础上列出操作选项
    echo -e "\n[+] 选择操作:"
    echo "1. 获取 mediainfo 信息"
    echo "2. 获取 bdinfo 信息"
    echo "3. 获取截图上传链接"
    echo "4. 设置下载目录"
    echo "0. 退出"

    echo -n "请选择操作: "
    read -r operation_choice

    case $operation_choice in
        1)
            # 处理 mediainfo 操作
            echo "正在获取 mediainfo 信息..."
            # 在这里执行 mediainfo 获取的相关操作
            ;;
        2)
            # 处理 bdinfo 操作
            echo "正在获取 bdinfo 信息..."
            # 在这里执行 bdinfo 获取的相关操作
            ;;
        3)
            # 处理截图上传操作
            echo "正在获取截图上传链接..."
            # 在这里执行截图上传操作
            ;;
        4)
            # 重新设置下载目录
            get_download_dir
            ;;
        0)
            # 退出脚本
            echo "退出脚本。"
            exit 0
            ;;
        *)
            echo "无效的选择。"
            ;;
    esac
}

# 调用主菜单
main_menu
