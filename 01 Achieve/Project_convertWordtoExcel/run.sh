#!/usr/bin/env bash

# Word to Excel 转换器运行脚本
# 自动检测虚拟环境并执行转换

set -e

# 获取脚本所在目录
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "$SCRIPT_DIR"

# 检查并创建虚拟环境
if [ ! -d ".venv" ]; then
    echo "[*] 未检测到 .venv 虚拟环境，正在创建..."
    python3 -m venv .venv
    echo "[+] 虚拟环境创建完毕！"
fi

# 检查依赖包，如果没有安装或需要更新则安装
echo "[*] 正在检查依赖包安装状态..."
# 使用国内阿里云镜像，加速安装
.venv/bin/pip install -r requirements.txt -i https://mirrors.aliyun.com/pypi/simple/

echo -e "[+] 依赖包检查完成！\n"

# 提示使用说明
if [ "$#" -eq 0 ]; then
    echo "================================================================="
    echo "  使用方法: ./run.sh [输入文件或目录] [选项]"
    echo "  示例:"
    echo "    - 转换单个文件: ./run.sh 安全台账.doc (默认拆分并填充合并单元格，方便统计)"
    echo "    - 保留合并的样式: ./run.sh 安全台账.doc --keep-merged"
    echo "    - 批量转换整个目录: ./run.sh ."
    echo "================================================================="
    exit 1
fi

# 运行核心 Python 转换脚本
.venv/bin/python3 convert.py "$@"
