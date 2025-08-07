#!/bin/bash

# 공통 함수 라이브러리

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# 로깅 함수들
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_debug() {
    if [[ "$DEBUG" == "1" ]]; then
        echo -e "${PURPLE}[DEBUG]${NC} $1"
    fi
}

# 프로그레스 바
show_progress() {
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local completed=$((width * current / total))
    
    printf "\r["
    printf "%*s" "$completed" | tr ' ' '='
    printf "%*s" $((width - completed)) | tr ' ' '-'
    printf "] %d%% (%d/%d)" "$percentage" "$current" "$total"
}

# 빠른 파일 유효성 검사
validate_apk_file() {
    local file="$1"
    
    # 파일 존재 확인
    if [[ ! -f "$file" ]]; then
        log_error "파일을 찾을 수 없습니다: $file"
        return 1
    fi
    
    # APK 확장자 확인
    if [[ ! "$file" =~ \.apk$ ]]; then
        log_error "APK 파일이 아닙니다: $file"
        return 1
    fi
    
    # 파일 크기 확인 (최소 1KB)
    local size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
    if [[ "$size" -lt 1024 ]]; then
        log_error "APK 파일 크기가 너무 작습니다: $(human_readable_size $size)"
        return 1
    fi
    
    return 0
}

# 디렉토리 생성
create_dir() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
        log_info "디렉토리 생성: $dir"
    fi
}

# 파일 크기를 사람이 읽기 쉬운 형태로 변환
human_readable_size() {
    local size=$1
    local units=("B" "KB" "MB" "GB" "TB")
    local unit=0
    
    while (( size > 1024 && unit < 4 )); do
        size=$((size / 1024))
        ((unit++))
    done
    
    echo "${size}${units[$unit]}"
}

# 예/아니오 확인
confirm() {
    local message="$1"
    local default="${2:-n}"
    
    if [[ "$default" == "y" ]]; then
        read -p "$message (Y/n): " -n 1 -r
        echo
        [[ $REPLY =~ ^[Yy]?$ ]]
    else
        read -p "$message (y/N): " -n 1 -r
        echo
        [[ $REPLY =~ ^[Yy]$ ]]
    fi
}

# 간단한 로딩 애니메이션
show_loading() {
    local message="$1"
    local duration="${2:-3}"
    
    echo -n "$message "
    for ((i=0; i<duration; i++)); do
        echo -n "."
        sleep 1
    done
    echo " 완료!"
}

# APK 정보 추출
get_apk_info() {
    local apk_file="$1"
    local aapt_cmd=""
    
    # 스크립트 디렉토리 찾기 (common.sh가 lib/ 디렉토리에 있음)
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    
    # 프로젝트 내부 Android SDK 경로 확인
    local project_android_sdk="$script_dir/android-sdk"
    
    if [[ -d "$project_android_sdk/build-tools" ]]; then
        # 프로젝트 내부 build-tools에서 aapt 찾기
        local build_tools_version=$(ls -1 "$project_android_sdk/build-tools/" | sort -V | tail -1)
        if [[ -n "$build_tools_version" ]]; then
            local project_aapt="$project_android_sdk/build-tools/$build_tools_version/aapt"
            local project_aapt2="$project_android_sdk/build-tools/$build_tools_version/aapt2"
            
            if [[ -f "$project_aapt2" ]]; then
                aapt_cmd="$project_aapt2"
            elif [[ -f "$project_aapt" ]]; then
                aapt_cmd="$project_aapt"
            fi
        fi
    fi
    
    # 프로젝트 내부에서 찾지 못했다면 시스템 PATH에서 찾기
    if [[ -z "$aapt_cmd" ]]; then
        if command -v aapt2 &> /dev/null; then
            aapt_cmd="aapt2"
        elif command -v aapt &> /dev/null; then
            aapt_cmd="aapt"
        fi
    fi
    
    # aapt를 찾지 못한 경우
    if [[ -z "$aapt_cmd" ]]; then
        log_error "aapt 또는 aapt2를 찾을 수 없습니다."
        log_info "Android SDK를 프로젝트에 설치해야 합니다."
        log_info "설치: ./setup.sh 실행"
        return 1
    fi
    
    # APK 기본 정보
    echo -e "${WHITE}APK 파일 정보:${NC}"
    echo "파일: $(basename "$apk_file")"
    echo "크기: $(human_readable_size $(stat -f%z "$apk_file" 2>/dev/null || stat -c%s "$apk_file" 2>/dev/null))"
    echo "사용 도구: $(basename "$aapt_cmd")"
    echo
    
    # 패키지 정보
    if [[ "$(basename "$aapt_cmd")" == "aapt2" ]]; then
        "$aapt_cmd" dump badging "$apk_file" 2>/dev/null | head -20
    else
        "$aapt_cmd" dump badging "$apk_file" 2>/dev/null | head -20
    fi
}