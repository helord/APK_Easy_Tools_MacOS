# macOS APK Easy Tools

> **Windows APK Easy Tool의 완전한 macOS 포트**  
> 프로젝트 폴더 내에서 모든 것이 해결되는 자체 포함형 APK 분석 도구

## 기능

### APK 분석
- APK 기본 정보 (패키지명, 버전, 크기 등)
- 권한(Permission) 분석
- 구성 요소(Activity, Service, Receiver, Provider) 분석
- APK 서명 정보 확인
- APK 내부 파일 구조 탐색

### 디컴파일/리컴파일
- APK → smali 코드 + 리소스 디컴파일
- APK → smali 코드만 디컴파일 (리소스 제외, -r 옵션)
- DEX → JAR 변환 및 Java 소스 디컴파일
- 디컴파일된 프로젝트 리빌드
- APK 서명 (디버그/릴리즈)
- Zipalign 최적화

### 편의 기능
- 대화형 메뉴 인터페이스
- 프로젝트 폴더 관리
- 키스토어 관리
- 작업 히스토리 및 로깅
- 임시 파일 자동 정리

## 빠른 시작

### 1. 클론 & 설치 (3분 완료)
```bash
git clone https://github.com/yourusername/macos-apk-easy-tools.git
cd macos-apk-easy-tools
./setup.sh
```

### 2. 실행
```bash
./apk-tools.sh
```

### 3. 사용
1. **APK 파일 선택** → 파인더에서 드래그 앤 드롭
2. **분석/디컴파일** → 메뉴에서 원하는 작업 선택
3. **완료!**

---

## 특징

### 완전 자체 포함 (Self-Contained)
- **모든 도구가 프로젝트 내부에 설치**
- **시스템 환경변수 건드리지 않음**
- **삭제 시 폴더만 지우면 끝**
- **Git 클론 후 바로 사용 가능**

### 필수 요구사항 (최소한)
- **macOS 10.15+** (Intel/Apple Silicon 모두 지원)
- **Java 8+** (대부분 macOS에 기본 설치)
  ```bash
  # Java 확인
  java -version
  
  # 없다면 설치
  brew install openjdk@11
  ```

## 사용법

### 기본 사용법
```bash
./apk-tools.sh
```

### 메뉴 구조
```
메인 메뉴
├── 1. APK 파일 선택
├── 2. APK 분석
│   ├── APK 기본 정보 보기
│   ├── APK 권한 분석
│   ├── APK 구성 요소 분석
│   ├── APK 서명 정보
│   └── APK 내부 파일 목록
├── 3. 디컴파일/리컴파일
│   ├── APK 디컴파일 (smali + 리소스)
│   ├── DEX to JAR 변환
│   ├── 디컴파일된 프로젝트 리컴파일
│   ├── 프로젝트 폴더 열기
│   └── 임시 파일 정리
├── 4. 설정
│   ├── 키스토어 관리
│   ├── 디버그 모드 토글
│   ├── 로그 보기
│   └── 캐시 정리
└── 5. 도움말
```

### 사용 예시

1. **APK 분석**
   - APK 파일 선택 → APK 분석 메뉴에서 원하는 분석 수행

2. **APK 디컴파일**
   - APK 파일 선택 → 디컴파일/리컴파일 → APK 디컴파일

3. **APK 리빌드**
   - 디컴파일된 프로젝트 수정 → 디컴파일된 프로젝트 리컴파일

## 디렉토리 구조
```
macos-apk-easy-tools/
├── apk-tools.sh          # 메인 스크립트
├── setup.sh              # 자동 설치 스크립트
├── uninstall.sh          # 완전 제거 스크립트
├── lib/
│   └── common.sh         # 공통 함수 라이브러리
├── android-sdk/          # Android SDK (자동 설치됨)
│   ├── cmdline-tools/
│   ├── build-tools/      # aapt, aapt2 포함
│   └── platform-tools/
├── tools/                # 외부 도구들 (apktool, dex2jar 등)
├── workspace/            # 작업 공간 (디컴파일된 프로젝트)
├── keystore/             # 키스토어 파일들
├── logs/                 # 로그 파일들
├── .env                  # 환경설정 (자동 생성)
└── README.md
```

**🎯 완전 자체 포함**: 모든 도구가 프로젝트 폴더 내부에 설치되어 시스템을 건드리지 않습니다.

## 요구사항
- **운영체제**: macOS 10.15+ (Intel/Apple Silicon 모두 지원)
- **의존성**: 
  - Homebrew
  - Java 11+
  - Xcode Command Line Tools

## 의존 도구
자동으로 다운로드/설치됩니다:
- **apktool**: APK 디컴파일/리컴파일
- **dex2jar**: DEX → JAR 변환
- **jd-cli**: Java 디컴파일러
- **aapt/aapt2**: Android Asset Packaging Tool
- **jarsigner**: APK 서명
- **zipalign**: APK 최적화

## 주의사항
**중요**: 이 도구는 교육 및 연구 목적으로만 사용해주세요.
- 본인이 소유하거나 권한이 있는 APK에 대해서만 사용하세요
- 다른 사람의 저작권을 존중하세요
- 역공학 시 관련 법률을 준수하세요
- 중요한 APK는 항상 백업하세요

## 문제 해결

### 자주 발생하는 문제

| 문제 | 해결 방법 |
|------|----------|
| **Java가 없다는 오류** | `brew install openjdk@11` 설치 |
| **권한 오류** | `chmod +x *.sh` 실행 권한 부여 |
| **의존성 누락** | `./setup.sh` 재실행 |
| **APK 파일 인식 안됨** | 드래그 앤 드롭으로 경로 입력 |

### 디버그
```bash
# 상세한 디버그 정보 출력
DEBUG=1 ./apk-tools.sh
```

### 완전 초기화
```bash
# 모든 것을 처음 상태로
./uninstall.sh        # 완전 제거
./setup.sh            # 새로 설치
```

## 라이선스
MIT License

## 기여하기
1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## 버전 히스토리
- v1.0.0: 초기 릴리즈
  - APK 분석 기능
  - 디컴파일/리컴파일 기능
  - APK 서명 기능
  - 대화형 메뉴 인터페이스