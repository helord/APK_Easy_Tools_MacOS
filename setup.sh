#!/bin/bash

# macOS APK Easy Tools - 의존성 설치 스크립트

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_DIR="$SCRIPT_DIR/tools"

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# 필수 요구사항 확인
check_requirements() {
    log_info "시스템 요구사항 확인 중..."
    
    # Java 확인 (필수)
    if ! command -v java &> /dev/null; then
        log_error "Java가 설치되지 않았습니다."
        echo "Java를 먼저 설치해주세요:"
        echo "  brew install openjdk@11"
        echo "또는 Oracle Java를 설치하세요."
        exit 1
    fi
    
    local java_version=$(java -version 2>&1 | head -1 | awk -F '"' '{print $2}' | awk -F '.' '{print $1}')
    if [[ "$java_version" -lt 8 ]]; then
        log_error "Java 8 이상이 필요합니다. 현재 버전: $java_version"
        exit 1
    fi
    
    log_success "Java 확인 완료 (버전: $java_version)"
    
    # 기본 도구 확인
    local missing_tools=()
    for tool in curl unzip; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "다음 도구들이 필요합니다: ${missing_tools[*]}"
        exit 1
    fi
    
    log_success "시스템 요구사항 확인 완료"
}

# Android SDK 도구 설치 (프로젝트 내부)
install_android_tools() {
    log_info "Android SDK 도구를 프로젝트 내부에 설치 중..."
    
    local android_sdk_dir="$SCRIPT_DIR/android-sdk"
    local cmdline_tools_dir="$android_sdk_dir/cmdline-tools"
    local latest_dir="$cmdline_tools_dir/latest"
    
    # 1. Android SDK 디렉토리 생성
    mkdir -p "$android_sdk_dir"
    mkdir -p "$cmdline_tools_dir"
    
    # 2. Command Line Tools 다운로드
    if [[ ! -d "$latest_dir" ]]; then
        log_info "Android Command Line Tools 다운로드 중..."
        cd "$android_sdk_dir"
        
        # macOS용 Command Line Tools 다운로드
        local cmdtools_url="https://dl.google.com/android/repository/commandlinetools-mac-11076708_latest.zip"
        curl -L -o commandlinetools.zip "$cmdtools_url"
        
        if [[ ! -f "commandlinetools.zip" ]]; then
            log_error "Command Line Tools 다운로드 실패"
            return 1
        fi
        
        # 압축 해제
        unzip -q commandlinetools.zip
        
        # 올바른 디렉토리 구조 생성
        if [[ -d "cmdline-tools" ]]; then
            mv cmdline-tools latest
            mkdir -p cmdline-tools
            mv latest cmdline-tools/
        fi
        
        # 정리
        rm commandlinetools.zip
        
        log_success "Command Line Tools 다운로드 완료"
    else
        log_info "Command Line Tools가 이미 설치되어 있습니다."
    fi
    
    # 3. SDK Manager로 필요한 도구들 설치
    local sdkmanager="$latest_dir/bin/sdkmanager"
    export ANDROID_SDK_ROOT="$android_sdk_dir"
    
    if [[ ! -f "$sdkmanager" ]]; then
        log_error "SDK Manager를 찾을 수 없습니다."
        return 1
    fi
    
    chmod +x "$sdkmanager"
    
    log_info "라이선스 동의 및 필요한 패키지 설치 중..."
    
    # 라이선스 자동 동의
    yes | "$sdkmanager" --licenses &> /dev/null || true
    
    # 필요한 패키지들 설치
    "$sdkmanager" --sdk_root="$android_sdk_dir" "build-tools;34.0.0" || log_warn "build-tools 설치 실패"
    "$sdkmanager" --sdk_root="$android_sdk_dir" "platform-tools" || log_warn "platform-tools 설치 실패"
    
    # 4. 설치 확인
    local aapt_path="$android_sdk_dir/build-tools/34.0.0/aapt"
    local aapt2_path="$android_sdk_dir/build-tools/34.0.0/aapt2"
    
    if [[ -f "$aapt_path" ]]; then
        log_success "aapt 설치 확인: $aapt_path"
    else
        log_error "aapt 설치 실패"
        return 1
    fi
    
    if [[ -f "$aapt2_path" ]]; then
        log_success "aapt2 설치 확인: $aapt2_path"
    else
        log_warn "aapt2 설치 실패 (aapt는 사용 가능)"
    fi
    
    # 5. 프로젝트 환경 설정 파일 생성
    cat > "$SCRIPT_DIR/.env" << EOF
# APK Easy Tools 환경설정
export ANDROID_SDK_ROOT="$android_sdk_dir"
export PATH="\$ANDROID_SDK_ROOT/build-tools/34.0.0:\$ANDROID_SDK_ROOT/platform-tools:\$PATH"
EOF
    
    log_success "Android SDK 도구를 프로젝트 내부에 설치 완료"
    log_info "모든 도구가 프로젝트 폴더 내에 설치되었습니다."
    
    cd "$SCRIPT_DIR"
}

# APK 분석 도구들 설치
install_apk_tools() {
    log_info "APK 분석 도구들 설치 중..."
    
    mkdir -p "$TOOLS_DIR"
    cd "$TOOLS_DIR"
    
    # apktool 설치
    if [ ! -f "apktool.jar" ]; then
        log_info "apktool 다운로드 중..."
        curl -L -o apktool.jar https://bitbucket.org/iBotPeaches/apktool/downloads/apktool_2.7.0.jar
        curl -L -o apktool https://raw.githubusercontent.com/iBotPeaches/Apktool/master/scripts/osx/apktool
        chmod +x apktool
        log_success "apktool 설치 완료"
    fi
    
    # dex2jar 설치
    if [ ! -d "dex-tools-v2.4" ]; then
        log_info "dex2jar 다운로드 중..."
        
        # 기존 파일 정리
        rm -f dex2jar.zip dex-tools-*.zip 2>/dev/null || true
        
        # 최신 릴리즈 URL 사용
        curl -L -o dex-tools-v2.4.zip "https://github.com/pxb1988/dex2jar/releases/download/v2.4/dex-tools-v2.4.zip"
        
        # 다운로드 확인
        if [ ! -f "dex-tools-v2.4.zip" ] || [ ! -s "dex-tools-v2.4.zip" ]; then
            log_warn "GitHub에서 다운로드 실패, 대체 URL 시도 중..."
            curl -L -o dex-tools-v2.4.zip "https://bitbucket.org/pxb1988/dex2jar/downloads/dex-tools-v2.4.zip"
        fi
        
        # ZIP 파일 유효성 검증
        if unzip -t dex-tools-v2.4.zip >/dev/null 2>&1; then
            unzip -q dex-tools-v2.4.zip
            chmod +x dex-tools-v2.4/*.sh 2>/dev/null || true
            rm dex-tools-v2.4.zip
            log_success "dex2jar 설치 완료"
        else
            log_error "dex2jar ZIP 파일이 손상되었습니다. 수동으로 다운로드해주세요."
            rm -f dex-tools-v2.4.zip
            log_info "대안: https://github.com/pxb1988/dex2jar/releases 에서 수동 다운로드"
        fi
    fi
    
    # jd-cli 설치 (Java Decompiler)
    if [ ! -f "jd-cli.jar" ]; then
        log_info "jd-cli 다운로드 중..."
        curl -L -o jd-cli.jar https://github.com/kwart/jd-cmd/releases/download/jd-cmd-1.1.0.Final/jd-cli-1.1.0-dist.jar
        log_success "jd-cli 설치 완료"
    fi
    
    cd "$SCRIPT_DIR"
}

# 키스토어 생성 (디버그용)
create_debug_keystore() {
    log_info "디버그 키스토어 생성 중..."
    
    KEYSTORE_DIR="$SCRIPT_DIR/keystore"
    mkdir -p "$KEYSTORE_DIR"
    
    if [ ! -f "$KEYSTORE_DIR/debug.keystore" ]; then
        keytool -genkey -v -keystore "$KEYSTORE_DIR/debug.keystore" \
            -storepass android -alias androiddebugkey -keypass android \
            -keyalg RSA -keysize 2048 -validity 10000 \
            -dname "CN=Android Debug,O=Android,C=US"
        log_success "디버그 키스토어 생성 완료"
    else
        log_info "디버그 키스토어가 이미 존재합니다."
    fi
}

# 실행 스크립트에 실행 권한 부여
set_permissions() {
    log_info "실행 권한 설정 중..."
    chmod +x "$SCRIPT_DIR/apk-tools.sh"
    chmod +x "$SCRIPT_DIR/lib/"*.sh 2>/dev/null || true
    log_success "실행 권한 설정 완료"
}

# 진행률 표시
show_progress() {
    local current=$1
    local total=$2
    local task="$3"
    local percentage=$((current * 100 / total))
    printf "\r[%d/%d] (%d%%) %s" "$current" "$total" "$percentage" "$task"
}

# 메인 설치 프로세스
main() {
    clear
    echo "======================================"
    echo "  macOS APK Easy Tools 설치 시작"
    echo "======================================"
    echo
    
    local total_steps=5
    local step=1
    
    show_progress $step $total_steps "시스템 요구사항 확인..."
    echo
    check_requirements
    ((step++))
    
    show_progress $step $total_steps "Android SDK 설치..."
    echo
    install_android_tools
    ((step++))
    
    show_progress $step $total_steps "APK 분석 도구 설치..."
    echo
    install_apk_tools
    ((step++))
    
    show_progress $step $total_steps "디버그 키스토어 생성..."
    echo
    create_debug_keystore
    ((step++))
    
    show_progress $step $total_steps "최종 설정..."
    echo
    set_permissions
    ((step++))
    
    echo
    echo "======================================"
    log_success "설치가 완료되었습니다!"
    echo "======================================"
    echo
    echo "사용 방법:"
    echo "   ./apk-tools.sh"
    echo
    echo "설치된 도구들:"
    echo "   - Android SDK (프로젝트 내부)"
    echo "   - apktool, dex2jar, jd-cli"
    echo "   - 디버그 키스토어"
    echo
}

# 스크립트 실행
main "$@"