# Carrot Jetson

Jetson Orin Nano Super를 Carrot에 연결하는 프로그램입니다.
콤마는 `carrot-wip`, Jetson 프로그램은 이 저장소에서 관리합니다.

**[설치 ZIP 하나 받기](https://upload.shind0.synology.me/downloads/jetson/v0.3.0-windows-preview/carrot-jetson-windows.zip)**

1. PC에서 ZIP을 **모두 압축 풀기** 합니다.
2. **`01_설치준비.cmd`**를 더블클릭합니다.
3. SD카드를 PC에 연결하고 **`02_SD카드설치.cmd`**를 더블클릭합니다.
4. **설치 완료**가 나오면 SD카드를 안전하게 제거하여 Jetson에 꽂습니다.

**나머지는 배치 파일이 알아서 합니다.** 별도 프로그램 설치나 명령 입력은 필요 없습니다.
카드를 선택할 때만 창의 안내를 따라 주세요. 선택한 카드의 기존 내용은 모두 지워집니다.

Windows 10/11 64비트 PC, 여유 공간 약 45GB, USB 카드 리더와 64GB 이상 microSD가 필요합니다.
대상은 Orin Nano Super 기본 보드입니다. 콤마는 Jetson 통합 이후 `carrot-wip`를 사용하세요.

현재 시험판이며, 이 자동 설치기로 기록한 실제 카드의 첫 부팅 시험은 아직 남아 있습니다.

처음 설치한 뒤 일반 프로그램·모델 갱신은 콤마가 지정한 서명 업데이트로 처리합니다.
Wi-Fi 정보도 연결한 콤마에서 자동으로 받습니다.

[소스 기준](UPSTREAM.json) · [라이선스](LICENSE)
