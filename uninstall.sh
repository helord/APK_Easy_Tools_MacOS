#!/bin/bash

# macOS APK Easy Tools - 완전 제거 스크립트

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# 로깅 함수
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

# 확인 함수
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

# 프로젝트 파일 정리
cleanup_project_files() {
    log_info "프로젝트 파일 정리 중..."
    
    # 작업 디렉토리 정리
    if [[ -d "$SCRIPT_DIR/workspace" ]]; then
        rm -rf "$SCRIPT_DIR/workspace"/*
        log_success "workspace 디렉토리 정리 완료"
    fi
    
    # 도구 디렉토리 정리
    if [[ -d "$SCRIPT_DIR/tools" ]]; then
        rm -rf "$SCRIPT_DIR/tools"/*
        log_success "tools 디렉토리 정리 완료"
    fi
    
    # 로그 디렉토리 정리
    if [[ -d "$SCRIPT_DIR/logs" ]]; then
        rm -rf "$SCRIPT_DIR/logs"/*
        log_success "logs 디렉토리 정리 완료"
    fi
    
    # 키스토어 정리 (확인 후)
    if [[ -d "$SCRIPT_DIR/keystore" ]] && [[ -n "$(ls -A "$SCRIPT_DIR/keystore" 2>/dev/null)" ]]; then
        if confirm "키스토어 파일도 삭제하시겠습니까?"; then
            rm -rf "$SCRIPT_DIR/keystore"/*
            log_success "keystore 디렉토리 정리 완료"
        else
            log_info "키스토어 파일은 보존됩니다"
        fi
    fi
    
    # 임시 파일 정리
    rm -rf /tmp/apktool* 2>/dev/null || true
    rm -rf /tmp/*dex2jar* 2>/dev/null || true
    log_success "임시 파일 정리 완료"
}

# Homebrew 패키지 제거
remove_homebrew_packages() {
    log_info "Homebrew 패키지 제거 중..."
    
    local packages_to_remove=(
        "android-platform-tools"
        "android-sdk"
        "openjdk@11"
    )
    
    local casks_to_remove=(
        "android-commandlinetools"
    )
    
    # 일반 패키지 제거
    for package in "${packages_to_remove[@]}"; do
        if brew list "$package" &> /dev/null; then
            if confirm "패키지 '$package'를 제거하시겠습니까?"; then
                brew uninstall "$package" 2>/dev/null || log_warn "$package 제거 실패"
                log_success "$package 제거 완료"
            fi
        else
            log_info "$package는 설치되지 않음"
        fi
    done
    
    # Cask 패키지 제거
    for cask in "${casks_to_remove[@]}"; do
        if brew list --cask "$cask" &> /dev/null; then
            if confirm "Cask '$cask'를 제거하시겠습니까?"; then
                brew uninstall --cask "$cask" 2>/dev/null || log_warn "$cask 제거 실패"
                log_success "$cask 제거 완료"
            fi
        else
            log_info "$cask는 설치되지 않음"
        fi
    done
    
    # Homebrew 정리
    if confirm "Homebrew 캐시를 정리하시겠습니까?"; then
        brew cleanup 2>/dev/null || log_warn "Homebrew cleanup 실패"
        log_success "Homebrew 캐시 정리 완료"
    fi
}

# 환경변수 설정 제거
remove_environment_settings() {
    log_info "환경변수 설정 제거 중..."
    
    local shell_files=(
        "$HOME/.zshrc"
        "$HOME/.bashrc"
        "$HOME/.bash_profile"
        "$HOME/.profile"
    )
    
    local env_patterns=(
        "ANDROID_SDK_ROOT"
        "android-sdk"
        "android-commandlinetools"
        "build-tools"
        "platform-tools"
        "openjdk@11"
    )
    
    for shell_file in "${shell_files[@]}"; do
        if [[ -f "$shell_file" ]]; then
            # 백업 생성
            cp "$shell_file" "${shell_file}.backup.$(date +%Y%m%d_%H%M%S)"
            log_info "백업 생성: ${shell_file}.backup.$(date +%Y%m%d_%H%M%S)"
            
            # 환경변수 관련 라인 제거
            for pattern in "${env_patterns[@]}"; do
                sed -i '' "/$pattern/d" "$shell_file" 2>/dev/null || true
            done
            
            log_success "$shell_file에서 Android 관련 설정 제거"
        fi
    done
    
    log_warn "변경사항을 적용하려면 터미널을 재시작하거나 'source ~/.zshrc'를 실행하세요"
}

# Android SDK 데이터 제거
remove_android_sdk_data() {
    log_info "Android SDK 데이터 제거 확인 중..."
    
    local android_dirs=(
        "/opt/homebrew/share/android-sdk"
        "/opt/homebrew/share/android-commandlinetools"
        "/usr/local/share/android-sdk"
        "/usr/local/share/android-commandlinetools"
        "$HOME/.android"
        "$HOME/Android/Sdk"
        "$HOME/Library/Android"
    )
    
    for android_dir in "${android_dirs[@]}"; do
        if [[ -d "$android_dir" ]]; then
            if confirm "Android 디렉토리 '$android_dir'를 제거하시겠습니까?"; then
                sudo rm -rf "$android_dir" 2>/dev/null || rm -rf "$android_dir" 2>/dev/null || log_warn "$android_dir 제거 실패"
                log_success "$android_dir 제거 완료"
            fi
        fi
    done
}

# Java 설정 확인 및 제거
handle_java_removal() {
    log_info "Java 설정 확인 중..."
    
    if java -version 2>&1 | grep -q "openjdk.*11"; then
        log_warn "OpenJDK 11이 설치되어 있습니다"
        if confirm "OpenJDK 11을 제거하시겠습니까? (다른 앱에서 사용 중일 수 있습니다)"; then
            brew uninstall openjdk@11 2>/dev/null || log_warn "OpenJDK 11 제거 실패"
            log_success "OpenJDK 11 제거 완료"
        else
            log_info "Java는 보존됩니다"
        fi
    fi
}

# 프로젝트 완전 제거 (선택사항)
remove_entire_project() {
    log_warn "이 옵션은 전체 프로젝트 디렉토리를 삭제합니다!"
    echo "현재 디렉토리: $SCRIPT_DIR"
    echo
    
    if confirm "전체 프로젝트를 완전히 삭제하시겠습니까? (복구 불가능)" "n"; then
        cd ..
        rm -rf "$SCRIPT_DIR"
        log_success "프로젝트 완전 삭제 완료"
        echo "프로젝트가 완전히 제거되었습니다."
        exit 0
    else
        log_info "프로젝트 파일들은 보존됩니다"
    fi
}

# 시스템 정리
cleanup_system() {
    log_info "시스템 정리 중..."
    
    # 사용자별 임시 파일 정리
    rm -rf "$HOME/Library/Caches/com.android.tools.build" 2>/dev/null || true
    rm -rf "$HOME/.gradle/caches/android*" 2>/dev/null || true
    
    # 시스템 임시 파일 정리
    sudo rm -rf /tmp/android* 2>/dev/null || true
    sudo rm -rf /tmp/apktool* 2>/dev/null || true
    
    log_success "시스템 정리 완료"
}

# 상태 확인
check_current_state() {
    echo "======================================"
    echo -e "${WHITE}  현재 설치 상태 확인${NC}"
    echo "======================================"
    echo
    
    # Java 확인
    if command -v java &> /dev/null; then
        echo -e "${GREEN}✓${NC} Java: $(java -version 2>&1 | head -1)"
    else
        echo -e "${RED}✗${NC} Java: 설치되지 않음"
    fi
    
    # Homebrew 패키지 확인
    local packages=("android-platform-tools" "android-sdk" "openjdk@11")
    for pkg in "${packages[@]}"; do
        if brew list "$pkg" &> /dev/null; then
            echo -e "${GREEN}✓${NC} Homebrew: $pkg"
        else
            echo -e "${RED}✗${NC} Homebrew: $pkg"
        fi
    done
    
    # Cask 확인
    if brew list --cask android-commandlinetools &> /dev/null; then
        echo -e "${GREEN}✓${NC} Cask: android-commandlinetools"
    else
        echo -e "${RED}✗${NC} Cask: android-commandlinetools"
    fi
    
    # 도구 확인
    local tools=("aapt" "aapt2")
    for tool in "${tools[@]}"; do
        if command -v "$tool" &> /dev/null; then
            echo -e "${GREEN}✓${NC} Tool: $tool ($(which $tool))"
        else
            echo -e "${RED}✗${NC} Tool: $tool"
        fi
    done
    
    # 프로젝트 파일 확인
    local project_dirs=("tools" "workspace" "logs" "keystore")
    for dir in "${project_dirs[@]}"; do
        if [[ -d "$SCRIPT_DIR/$dir" ]] && [[ -n "$(ls -A "$SCRIPT_DIR/$dir" 2>/dev/null)" ]]; then
            echo -e "${GREEN}✓${NC} Directory: $dir (파일 있음)"
        else
            echo -e "${RED}✗${NC} Directory: $dir (비어있음)"
        fi
    done
    
    echo
}

# 메인 메뉴
main_menu() {
    while true; do
        clear
        echo "======================================"
        echo -e "${WHITE}  macOS APK Easy Tools - 제거 도구${NC}"
        echo "======================================"
        echo
        echo "1. 현재 설치 상태 확인"
        echo "2. 프로젝트 파일만 정리"
        echo "3. Homebrew 패키지 제거"
        echo "4. 환경변수 설정 제거"
        echo "5. Android SDK 데이터 제거"
        echo "6. 시스템 정리"
        echo "7. 완전 제거 (모든 항목)"
        echo "8. 프로젝트 완전 삭제"
        echo "0. 종료"
        echo
        
        read -p "선택하세요 (0-8): " choice
        
        case $choice in
            1) 
                check_current_state
                read -p "계속하려면 Enter를 누르세요..."
                ;;
            2) 
                cleanup_project_files
                read -p "계속하려면 Enter를 누르세요..."
                ;;
            3) 
                remove_homebrew_packages
                read -p "계속하려면 Enter를 누르세요..."
                ;;
            4) 
                remove_environment_settings
                read -p "계속하려면 Enter를 누르세요..."
                ;;
            5) 
                remove_android_sdk_data
                read -p "계속하려면 Enter를 누르세요..."
                ;;
            6) 
                cleanup_system
                read -p "계속하려면 Enter를 누르세요..."
                ;;
            7) 
                echo
                log_warn "완전 제거를 시작합니다..."
                cleanup_project_files
                remove_homebrew_packages
                remove_environment_settings
                remove_android_sdk_data
                handle_java_removal
                cleanup_system
                log_success "완전 제거가 완료되었습니다!"
                read -p "계속하려면 Enter를 누르세요..."
                ;;
            8) 
                remove_entire_project
                ;;
            0) 
                echo "제거 도구를 종료합니다."
                exit 0 
                ;;
            *) 
                log_warn "잘못된 선택입니다." 
                sleep 1
                ;;
        esac
    done
}

# 스크립트 시작
echo "======================================"
echo -e "${WHITE}  macOS APK Easy Tools - 제거 도구${NC}"
echo "======================================"
echo
echo -e "${YELLOW}주의: 이 스크립트는 APK Easy Tools와 관련된 모든 설정을 제거합니다.${NC}"
echo -e "${YELLOW}제거 전에 중요한 데이터는 백업하시기 바랍니다.${NC}"
echo

if confirm "제거 도구를 시작하시겠습니까?"; then
    main_menu
else
    echo "제거 도구를 취소합니다."
    exit 0
fi