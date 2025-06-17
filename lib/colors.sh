#!/usr/bin/env bash

# 禁用未定义变量检查，避免颜色变量错误
set +u

# 颜色代码 (增加对tput的支持)
if command -v tput >/dev/null 2>&1; then
    GR="$(tput setaf 2)"
    GREEN="$(tput setaf 2)"
    RE="$(tput setaf 1)"
    RED="$(tput setaf 1)"
    YE="$(tput setaf 3)"
    YELLOW="$(tput setaf 3)"
    BLUE="$(tput setaf 4)"
    PURPLE="$(tput setaf 5)"
    CYAN="$(tput setaf 6)"
    WHITE="$(tput setaf 7)"
    GRB="$(tput setab 2)$(tput setaf 7)"
    REB="$(tput setab 1)$(tput setaf 7)"
    NC="$(tput sgr0)"
else
    GR="\033[32m"
    GREEN='\033[0;32m'
    RE="\033[31m"
    RED='\033[0;31m'
    YE='\033[1;33m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    PURPLE='\033[0;35m'
    CYAN='\033[0;36m'
    WHITE='\033[1;37m'
    GRB="\033[42;37m"
    REB="\033[41;37m"
    NC='\033[0m' # No Color
fi

# 导出颜色变量，确保在所有子shell中可用
export GR GREEN RE RED YELLOW BLUE PURPLE CYAN WHITE GRB REB NC

Inf="${GR}[信息]${NC}:"
Err="${RE}[错误]${NC}:"
Tip="${GR}[提示]${NC}:"
SETTAG="${GR}-> 已设置${NC}"
UNSETTAG="${RE}-> 未设置${NC}"
