#!/bin/bash

# macOS APK Easy Tools - 메인 스크립트

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$SCRIPT_DIR/workspace"
TOOLS_DIR="$SCRIPT_DIR/tools"
LIB_DIR="$SCRIPT_DIR/lib"
LOGS_DIR="$SCRIPT_DIR/logs"
KEYSTORE_DIR="$SCRIPT_DIR/keystore"

# 공통 함수 로드
source "$LIB_DIR/common.sh"

# 전역 변수
CURRENT_APK=""
CURRENT_PROJECT=""
VERSION="1.0.0"

# 프로젝트 환경 로드
load_project_environment() {
    # 프로젝트 환경설정 로드
    if [[ -f "$SCRIPT_DIR/.env" ]]; then
        source "$SCRIPT_DIR/.env"
        log_debug "프로젝트 환경설정 로드됨"
    fi
    
    # 프로젝트 내부 Android SDK 경로 설정
    local project_android_sdk="$SCRIPT_DIR/android-sdk"
    if [[ -d "$project_android_sdk" ]]; then
        export ANDROID_SDK_ROOT="$project_android_sdk"
        
        # build-tools 경로 추가
        if [[ -d "$ANDROID_SDK_ROOT/build-tools" ]]; then
            local build_tools_version=$(ls -1 "$ANDROID_SDK_ROOT/build-tools/" | sort -V | tail -1)
            if [[ -n "$build_tools_version" ]]; then
                export PATH="$ANDROID_SDK_ROOT/build-tools/$build_tools_version:$ANDROID_SDK_ROOT/platform-tools:$PATH"
                log_debug "Android SDK 경로 설정: $ANDROID_SDK_ROOT"
            fi
        fi
    fi
}

# 의존성 확인
check_dependencies() {
    local missing_deps=()
    
    # 프로젝트 환경 로드
    load_project_environment
    
    # Java 확인
    if ! command -v java &> /dev/null; then
        missing_deps+=("java")
    fi
    
    # Android SDK 도구 확인 (프로젝트 내부)
    local project_aapt="$SCRIPT_DIR/android-sdk/build-tools/*/aapt"
    local project_aapt2="$SCRIPT_DIR/android-sdk/build-tools/*/aapt2"
    
    if [[ ! -f $project_aapt ]] && ! command -v aapt &> /dev/null && ! command -v aapt2 &> /dev/null; then
        missing_deps+=("aapt/aapt2")
    fi
    
    # 도구 확인
    if [[ ! -f "$TOOLS_DIR/apktool" ]]; then
        missing_deps+=("apktool")
    fi
    
    if [[ ! -d "$TOOLS_DIR/dex-tools-v2.4" ]]; then
        missing_deps+=("dex2jar")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "다음 의존성이 누락되었습니다: ${missing_deps[*]}"
        echo "setup.sh를 실행하여 의존성을 설치하세요."
        if [[ " ${missing_deps[*]} " =~ " aapt/aapt2 " ]]; then
            echo "Android SDK를 프로젝트 내부에 설치해야 합니다."
            echo "./setup.sh를 실행하세요."
        fi
        exit 1
    fi
    
    log_debug "모든 의존성 확인 완료"
}

# APK 파일 선택
select_apk() {
    clear
    echo "======================================"
    echo "  APK 파일 선택"
    echo "======================================"
    echo
    echo "팁: 파인더에서 APK 파일을 드래그해서 터미널에 놓으면 경로가 자동 입력됩니다"
    echo
    echo -n "APK 파일 경로 입력: "
    read -r apk_path
    
    # 입력값이 없는 경우
    if [[ -z "$apk_path" ]]; then
        log_warn "APK 파일 경로를 입력해주세요."
        read -p "계속하려면 Enter를 누르세요..."
        return 1
    fi
    
    # 따옴표 및 공백 제거
    apk_path="${apk_path//\"/}"
    apk_path="${apk_path//\'/}"
    apk_path="${apk_path// /\\ }"
    
    echo
    log_info "APK 파일 검증 중..."
    
    # 파일 존재 확인
    if [[ ! -f "$apk_path" ]]; then
        log_error "파일을 찾을 수 없습니다: $apk_path"
        read -p "계속하려면 Enter를 누르세요..."
        return 1
    fi
    
    # APK 파일 확인
    if [[ ! "$apk_path" =~ \.apk$ ]]; then
        log_error "APK 파일이 아닙니다. 확장자를 확인해주세요."
        read -p "계속하려면 Enter를 누르세요..."
        return 1
    fi
    
    CURRENT_APK="$apk_path"
    log_success "APK 파일 선택 완료: $(basename "$CURRENT_APK")"
    
    # 간단한 APK 정보 표시
    echo
    echo "선택된 APK 정보:"
    echo "   파일명: $(basename "$CURRENT_APK")"
    echo "   크기: $(human_readable_size $(stat -f%z "$CURRENT_APK" 2>/dev/null || stat -c%s "$CURRENT_APK" 2>/dev/null))"
    echo
    
    read -p "APK 정보를 확인하려면 Enter를 누르세요..."
    return 0
}

# APK 분석 메뉴
apk_analyze_menu() {
    if [[ -z "$CURRENT_APK" ]]; then
        log_warn "먼저 APK 파일을 선택해주세요."
        return 0
    fi
    
    while true; do
        echo
        echo "======================================"
        echo -e "${CYAN}  APK 분석 메뉴${NC}"
        echo "======================================"
        echo "현재 APK: $(basename "$CURRENT_APK")"
        echo
        echo "1. APK 기본 정보 보기"
        echo "2. APK 권한 분석"
        echo "3. APK 구성 요소 분석"
        echo "4. APK 서명 정보"
        echo "5. APK 내부 파일 목록"
        echo "0. 뒤로가기"
        echo
        
        read -p "선택하세요 (0-5): " choice
        
        case $choice in
            1) show_apk_basic_info ;;
            2) analyze_permissions ;;
            3) analyze_components ;;
            4) show_signature_info ;;
            5) list_apk_contents ;;
            0) return 0 ;;
            *) log_warn "잘못된 선택입니다." ;;
        esac
    done
}

# APK 기본 정보 표시
show_apk_basic_info() {
    echo
    log_info "APK 기본 정보 분석 중..."
    get_apk_info "$CURRENT_APK"
    echo
    read -p "계속하려면 Enter를 누르세요..."
}

# 권한 분석
analyze_permissions() {
    echo
    log_info "APK 권한 분석 중..."
    
    if command -v aapt2 &> /dev/null; then
        aapt2 dump permissions "$CURRENT_APK" 2>/dev/null || aapt2 dump badging "$CURRENT_APK" 2>/dev/null | grep "uses-permission"
    elif command -v aapt &> /dev/null; then
        aapt dump permissions "$CURRENT_APK" 2>/dev/null || aapt dump badging "$CURRENT_APK" 2>/dev/null | grep "uses-permission"
    else
        log_error "aapt 도구를 찾을 수 없습니다."
    fi
    
    echo
    read -p "계속하려면 Enter를 누르세요..."
}

# 구성 요소 분석
analyze_components() {
    echo
    log_info "APK 구성 요소 분석 중..."
    
    if command -v aapt2 &> /dev/null; then
        aapt2 dump badging "$CURRENT_APK" 2>/dev/null | grep -E "(activity|service|receiver|provider)"
    elif command -v aapt &> /dev/null; then
        aapt dump badging "$CURRENT_APK" 2>/dev/null | grep -E "(activity|service|receiver|provider)"
    else
        log_error "aapt 도구를 찾을 수 없습니다."
    fi
    
    echo
    read -p "계속하려면 Enter를 누르세요..."
}

# 서명 정보 표시
show_signature_info() {
    echo
    log_info "APK 서명 정보 확인 중..."
    
    # keytool을 사용하여 서명 정보 확인
    unzip -p "$CURRENT_APK" META-INF/*.RSA 2>/dev/null | keytool -printcert || \
    unzip -p "$CURRENT_APK" META-INF/*.DSA 2>/dev/null | keytool -printcert || \
    log_warn "서명 정보를 찾을 수 없습니다."
    
    echo
    read -p "계속하려면 Enter를 누르세요..."
}

# APK 내부 파일 목록
list_apk_contents() {
    echo
    log_info "APK 내부 파일 목록:"
    echo
    unzip -l "$CURRENT_APK" | head -50
    echo
    read -p "계속하려면 Enter를 누르세요..."
}

# 디컴파일 메뉴
decompile_menu() {
    if [[ -z "$CURRENT_APK" ]]; then
        log_warn "먼저 APK 파일을 선택해주세요."
        return 0
    fi
    
    while true; do
        echo
        echo "======================================"
        echo "  디컴파일/리컴파일 메뉴"
        echo "======================================"
        echo "현재 APK: $(basename "$CURRENT_APK")"
        echo
        echo "1. APK 디컴파일 (smali + 리소스)"
        echo "2. APK 디컴파일 (smali만, 리소스 제외)"
        echo "3. DEX to JAR 변환"
        echo "4. 디컴파일된 프로젝트 리컴파일"
        echo "5. 프로젝트 폴더 열기"
        echo "6. 임시 파일 정리"
        echo "0. 뒤로가기"
        echo
        
        read -p "선택하세요 (0-6): " choice
        
        case $choice in
            1) decompile_apk_full ;;
            2) decompile_apk_no_resources ;;
            3) dex_to_jar ;;
            4) recompile_apk ;;
            5) open_project_folder ;;
            6) cleanup_workspace ;;
            0) return 0 ;;
            *) log_warn "잘못된 선택입니다." ;;
        esac
    done
}

# APK 완전 디컴파일 (smali + 리소스)
decompile_apk_full() {
    echo
    log_info "APK 완전 디컴파일 시작 (smali + 리소스)..."
    
    local apk_name=$(basename "$CURRENT_APK" .apk)
    local output_dir="$WORKSPACE_DIR/${apk_name}_full"
    
    create_dir "$output_dir"
    
    # apktool을 사용하여 완전 디컴파일
    cd "$TOOLS_DIR"
    if ./apktool d "$CURRENT_APK" -o "$output_dir" -f; then
        CURRENT_PROJECT="$output_dir"
        log_success "완전 디컴파일 완료: $output_dir"
        echo
        echo "디컴파일된 내용:"
        echo "  - smali/ : DEX 코드"
        echo "  - res/   : 리소스 파일들"
        echo "  - AndroidManifest.xml"
    else
        log_error "디컴파일 실패"
        return 1
    fi
    
    echo
    read -p "계속하려면 Enter를 누르세요..."
}

# APK 코드만 디컴파일 (리소스 제외)
decompile_apk_no_resources() {
    echo
    log_info "APK 코드만 디컴파일 시작 (리소스 제외, -r 옵션)..."
    
    local apk_name=$(basename "$CURRENT_APK" .apk)
    local output_dir="$WORKSPACE_DIR/${apk_name}_no_res"
    
    create_dir "$output_dir"
    
    # apktool -r 옵션으로 리소스 제외 디컴파일
    cd "$TOOLS_DIR"
    if ./apktool d "$CURRENT_APK" -o "$output_dir" -r -f; then
        CURRENT_PROJECT="$output_dir"
        log_success "코드 디컴파일 완료: $output_dir"
        echo
        echo "디컴파일된 내용:"
        echo "  - smali/ : DEX 코드만"
        echo "  - AndroidManifest.xml"
        echo "  - 리소스 파일 제외 (빠른 분석용)"
    else
        log_error "디컴파일 실패"
        return 1
    fi
    
    echo
    read -p "계속하려면 Enter를 누르세요..."
}

# DEX to JAR 변환
dex_to_jar() {
    echo
    log_info "DEX to JAR 변환 시작..."
    
    local apk_name=$(basename "$CURRENT_APK" .apk)
    local output_dir="$WORKSPACE_DIR/${apk_name}_jar"
    
    create_dir "$output_dir"
    
    # dex2jar 사용
    cd "$TOOLS_DIR/dex-tools-v2.4"
    if ./d2j-dex2jar.sh "$CURRENT_APK" -o "$output_dir/${apk_name}.jar"; then
        log_success "DEX to JAR 변환 완료: $output_dir/${apk_name}.jar"
        
        # JAR 파일을 JD-CLI로 디컴파일
        if [[ -f "../jd-cli.jar" ]]; then
            log_info "JAR 파일 디컴파일 중..."
            java -jar ../jd-cli.jar "$output_dir/${apk_name}.jar" -od "$output_dir/src"
            log_success "Java 소스 코드 디컴파일 완료: $output_dir/src"
        fi
    else
        log_error "DEX to JAR 변환 실패"
        return 1
    fi
    
    echo
    read -p "계속하려면 Enter를 누르세요..."
}

# 프로젝트 리컴파일
recompile_apk() {
    if [[ -z "$CURRENT_PROJECT" ]]; then
        log_warn "먼저 APK를 디컴파일해주세요."
        return 0
    fi
    
    echo
    log_info "APK 리컴파일 시작..."
    
    local output_apk="${CURRENT_PROJECT}_rebuilt.apk"
    
    # apktool을 사용하여 리컴파일
    cd "$TOOLS_DIR"
    if ./apktool b "$CURRENT_PROJECT" -o "$output_apk"; then
        log_success "리컴파일 완료: $output_apk"
        
        # 서명 여부 확인
        if confirm "APK에 서명하시겠습니까?"; then
            sign_apk "$output_apk"
        fi
    else
        log_error "리컴파일 실패"
        return 1
    fi
    
    echo
    read -p "계속하려면 Enter를 누르세요..."
}

# APK 서명
sign_apk() {
    local apk_file="$1"
    local signed_apk="${apk_file%.*}_signed.apk"
    
    echo
    log_info "APK 서명 중..."
    
    # jarsigner로 서명
    if jarsigner -verbose -sigalg SHA1withRSA -digestalg SHA1 \
        -keystore "$KEYSTORE_DIR/debug.keystore" \
        -storepass android \
        "$apk_file" androiddebugkey; then
        
        # zipalign 최적화
        if command -v zipalign &> /dev/null; then
            zipalign -v 4 "$apk_file" "$signed_apk"
            mv "$signed_apk" "$apk_file"
            log_success "APK 서명 및 최적화 완료"
        else
            log_success "APK 서명 완료 (zipalign 없음)"
        fi
    else
        log_error "APK 서명 실패"
        return 1
    fi
}

# 프로젝트 폴더 열기
open_project_folder() {
    if [[ -z "$CURRENT_PROJECT" ]]; then
        log_warn "먼저 APK를 디컴파일해주세요."
        return 0
    fi
    
    log_info "프로젝트 폴더 열기: $CURRENT_PROJECT"
    open "$CURRENT_PROJECT"
}

# 워크스페이스 정리
cleanup_workspace() {
    echo
    if confirm "워크스페이스를 정리하시겠습니까? 모든 디컴파일된 파일이 삭제됩니다."; then
        rm -rf "$WORKSPACE_DIR"/*
        log_success "워크스페이스 정리 완료"
        CURRENT_PROJECT=""
    fi
}

# 설정 메뉴
settings_menu() {
    while true; do
        echo
        echo "======================================"
        echo -e "${CYAN}  설정 메뉴${NC}"
        echo "======================================"
        echo
        echo "1. 키스토어 관리"
        echo "2. 디버그 모드 토글"
        echo "3. 로그 보기"
        echo "4. 캐시 정리"
        echo "0. 뒤로가기"
        echo
        
        read -p "선택하세요 (0-4): " choice
        
        case $choice in
            1) keystore_management ;;
            2) toggle_debug_mode ;;
            3) view_logs ;;
            4) clear_cache ;;
            0) return 0 ;;
            *) log_warn "잘못된 선택입니다." ;;
        esac
    done
}

# 키스토어 관리
keystore_management() {
    echo
    echo "현재 키스토어:"
    ls -la "$KEYSTORE_DIR/" 2>/dev/null || log_info "키스토어 없음"
    echo
    read -p "계속하려면 Enter를 누르세요..."
}

# 디버그 모드 토글
toggle_debug_mode() {
    if [[ "$DEBUG" == "1" ]]; then
        export DEBUG="0"
        log_info "디버그 모드 비활성화"
    else
        export DEBUG="1"
        log_info "디버그 모드 활성화"
    fi
}

# 로그 보기
view_logs() {
    if [[ -d "$LOGS_DIR" ]]; then
        ls -la "$LOGS_DIR/"
    else
        log_info "로그 파일이 없습니다."
    fi
    echo
    read -p "계속하려면 Enter를 누르세요..."
}

# 캐시 정리
clear_cache() {
    log_info "캐시 정리 중..."
    rm -rf /tmp/apktool* 2>/dev/null || true
    log_success "캐시 정리 완료"
}

# 메인 메뉴
main_menu() {
    while true; do
        clear
        echo "======================================="
        echo -e "${WHITE}  macOS APK Easy Tools v$VERSION${NC}"
        echo "======================================="
        echo
        
        # 현재 상태 표시
        if [[ -n "$CURRENT_APK" ]]; then
            echo -e "현재 APK: ${GREEN}$(basename "$CURRENT_APK")${NC}"
            local apk_size=$(human_readable_size $(stat -f%z "$CURRENT_APK" 2>/dev/null || stat -c%s "$CURRENT_APK" 2>/dev/null))
            echo -e "   크기: ${BLUE}$apk_size${NC}"
        else
            echo -e "APK 파일: ${YELLOW}선택되지 않음${NC}"
        fi
        
        if [[ -n "$CURRENT_PROJECT" ]]; then
            echo -e "프로젝트: ${GREEN}$(basename "$CURRENT_PROJECT")${NC}"
        fi
        
        echo
        echo "=============== 메뉴 ================="
        echo -e "${CYAN}1.${NC} APK 파일 선택"
        echo -e "${CYAN}2.${NC} APK 분석"
        echo -e "${CYAN}3.${NC} 디컴파일/리컴파일"
        echo -e "${CYAN}4.${NC} 설정"
        echo -e "${CYAN}5.${NC} 도움말"
        echo -e "${CYAN}0.${NC} 종료"
        echo "======================================="
        echo
        
        echo -n "선택하세요 (0-5): "
        read choice
        
        case $choice in
            1) select_apk ;;
            2) 
                if [[ -z "$CURRENT_APK" ]]; then
                    log_warn "먼저 APK 파일을 선택해주세요."
                    read -p "계속하려면 Enter를 누르세요..."
                else
                    apk_analyze_menu
                fi
                ;;
            3) 
                if [[ -z "$CURRENT_APK" ]]; then
                    log_warn "먼저 APK 파일을 선택해주세요."
                    read -p "계속하려면 Enter를 누르세요..."
                else
                    decompile_menu
                fi
                ;;
            4) settings_menu ;;
            5) show_help ;;
            0) 
                echo
                log_success "macOS APK Easy Tools를 이용해주셔서 감사합니다!"
                exit 0 
                ;;
            *) 
                log_warn "잘못된 선택입니다. 0-5 사이의 숫자를 입력해주세요."
                sleep 1
                ;;
        esac
    done
}

# 도움말 표시
show_help() {
    echo
    echo "======================================"
    echo -e "${WHITE}  도움말${NC}"
    echo "======================================"
    echo
    echo "macOS APK Easy Tools는 APK 파일을 분석, 디컴파일, 리컴파일할 수 있는 도구입니다."
    echo
    echo "주요 기능:"
    echo "• APK 파일 분석 (권한, 구성요소, 서명 정보)"
    echo "• APK 디컴파일 (smali 코드 + 리소스)"
    echo "• DEX to JAR 변환 및 Java 소스 디컴파일"
    echo "• APK 리컴파일 및 서명"
    echo "• 키스토어 관리"
    echo
    echo "사용 전 주의사항:"
    echo "• 합법적인 목적으로만 사용하세요"
    echo "• 다른 사람의 저작권을 존중하세요"
    echo "• 백업을 항상 유지하세요"
    echo
    read -p "계속하려면 Enter를 누르세요..."
}

# 에러 핸들링 및 정리
cleanup_on_exit() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        log_error "예기치 못한 오류가 발생했습니다. (종료 코드: $exit_code)"
    fi
    
    # 임시 파일 정리
    rm -rf /tmp/apktool_* 2>/dev/null || true
    rm -rf /tmp/dex2jar_* 2>/dev/null || true
}

# 초기화
init() {
    # 에러 발생 시 정리 함수 실행
    trap cleanup_on_exit EXIT ERR
    
    # 필요한 디렉토리 생성
    create_dir "$WORKSPACE_DIR"
    create_dir "$LOGS_DIR" 
    create_dir "$KEYSTORE_DIR"
    
    # 로그 파일 생성
    local log_file="$LOGS_DIR/apk-tools-$(date +%Y%m%d_%H%M%S).log"
    touch "$log_file"
    
    # 의존성 확인
    if ! check_dependencies; then
        echo
        echo "의존성 확인 실패. 설치가 필요합니다."
        if confirm "지금 설치하시겠습니까?"; then
            exec "./setup.sh"
        else
            echo "설치를 취소합니다."
            exit 1
        fi
    fi
}

# 메인 함수
main() {
    # 초기화
    init
    
    # 메인 메뉴 시작
    main_menu
}

# 스크립트 시작
main "$@"