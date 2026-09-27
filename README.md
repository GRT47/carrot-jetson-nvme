# Carrot Jetson

Jetson Orin Nano Super용 Carrot 추론 서버, USB 계기판, 네비 영상 전달 및 서명 업데이트 도구입니다.
NVIDIA 기본 OS 위에 설치하는 애플리케이션 소스이며, OS 이미지나 모델 가중치는 Git에 포함하지 않습니다.

현재 대상은 **L4T 36.4.7 / TensorRT 10.3.0 / aarch64**입니다. 다른 JetPack·보드·QSPI 조합을 검증한 배포판으로 보지 마세요.
최초 소스 기준은 [UPSTREAM.json](UPSTREAM.json)에 기록되어 있습니다. 기존 Carrot 공유 렌더러·스키마 경로는 호환성을 위해 유지합니다.

## 설치와 업데이트

최초 설치는 별도로 검증한 SD 이미지로 합니다. USB Wi-Fi 전달을 지원하는 Carrot에 연결하면,
콤마에 저장된 Wi-Fi 접속 정보를 USB로 받아 Jetson이 자동 연결합니다. 인터넷이나 모델 준비 전에 전달합니다.
이번 검증 조합은 콤마 `carrot-jetlink`의 `526f81421c`와 Jetson 런타임 `f2b22dc`입니다.
일반 `carrot-wip`의 임의 버전까지 지원한다는 뜻은 아닙니다.
[v0.2.0-preview](https://github.com/ajouatom/carrot-jetson/releases/tag/v0.2.0-preview)에
이미지 버전·해시·설치 안내와 검증 상태를 함께 제공합니다. 새 이미지의 실물 첫 부팅 검증은 별도이며,
GitHub의 `manifest.json`은 NAS 런타임 업데이트 지정 파일입니다.
콤마의 SSID·비밀번호 변경은 주기적으로 반영하며, 현재 연결된 Wi-Fi를 우선합니다.
다른 콤마로 옮기면 이전 콤마에서 자동으로 받은 프로필을 교체합니다. 수동으로 만든 Jetson 프로필은 삭제하지 않습니다.
일반 WPA/WPA2 PSK, WPA3 SAE 및 공개 Wi-Fi를 지원합니다. 기업용 인증과 웹 로그인이 필요한 Wi-Fi는 자동 설정 대상이 아닙니다.
인터넷이 없더라도 설치된 호환 모델의 USB 추론·화면 전달은 가능합니다. 업데이트 다운로드에는 인터넷이 필요합니다.
SSH 접속이 필요하면 개인 공개키만 `CARROTSETUP/setup.json`에 넣을 수 있습니다. Wi-Fi를 직접 지정하는 기존 방식도 유지합니다.
비밀번호는 일반 HUD·상태 로그에 포함하지 않고, USB 전용 메시지와 접근 권한 0600의 임시 파일·NetworkManager 프로필로 처리합니다.
USB로 연결한 콤마를 Wi-Fi 설정 제공자로 신뢰하는 구조이며, 콤마의 인터넷을 USB로 공유하는 기능은 아닙니다.
개인 설정이 들어간 SD를 다른 사용자에게 복제하지 마세요. 원본 이미지에는 개인 설정과 장치 키를 넣지 않습니다.

일반 업데이트는 이미지를 다시 쓰지 않습니다.

1. Carrot 버전이 서명된 Jetson 릴리스와 모델을 지정합니다.
2. Jetson은 신선한 offroad 상태를 확인한 뒤 NAS에서 해당 파일을 자동으로 받습니다.
3. 서명·해시·크기·OS/런타임·모델 계약을 검사해 별도 버전 폴더에 준비합니다.
4. 다음 부팅 때 추론 엔진 검증을 통과하면 교체합니다. 적용 중 실패하면 이전 버전을 유지합니다.

P단은 offroad와 다릅니다. 자동 확인은 부팅 약 2분 후, 이후 약 15분 간격이며 전원과 네트워크가 유지되어야 합니다.
지정 릴리스가 없는 구형 Carrot은 기존 NAS stable 채널을 사용합니다. JetPack·TensorRT·QSPI 변경은 별도 OS 유지보수입니다.
실행 중인 `/opt/carrot-jetlink/current`에서 `git pull`하지 않습니다.

개발자는 이 공개 저장소를 인증키 없이 clone/pull할 수 있습니다. 차량은 GitHub 비밀키 없이 서명된 배포 패키지를 받습니다.
커밋을 push하는 것과 안정 릴리스를 발행하는 것은 분리합니다. 서명 개인키는 개발자의 별도 저장소에만 보관합니다.

## 릴리스 만들기

### C-to-C 역할 hotfix

P3768/L4T 36.4.7에서 C-to-C가 반대 역할로 연결되는 경우를 위한
[USB-C hotfix](tools/jetlink/USB-C-HOTFIX.md)가 있습니다. 기존 v0.2.0 이미지에는
별도로 설치해야 하며, 새 이미지 생성 도구에는 포함됩니다. 기존 매체의
전체 재기록 없이 SSH로 설치할 수 있습니다. 공용 이미지는 SSH 서버만
제공하고 개인 관리키는 포함하지 않으므로, 자신의 공개키를 CARROTSETUP에
등록해야 로그인할 수 있습니다. Wi-Fi 자동 전달이 SSH 인증까지 설정하는
것은 아닙니다.

깨끗한 커밋에서 다음 명령으로 실행 패키지를 만들고 서명합니다.

```sh
mkdir -p dist
python tools/jetlink/build_host_bundle.py dist/precompiled-runtime.tar.gz
python tools/jetlink/sign_release.py \
  --bundle dist/precompiled-runtime.tar.gz \
  --key /secure/location/release-signing-private.pem \
  --model-url https://upload.shind0.synology.me/models/carrot-jetlink-cinque-v2/big_driving_supercombo.onnx \
  --output dist/manifest.json
```

`manifest.json`이 가리키는 NAS 버전 디렉터리에 패키지를 올리고 전체 해시를 다시 확인합니다.
해당 릴리스로 기기 시험을 마친 뒤 GitHub Release에 서명된 manifest를 게시하고,
Carrot의 `openpilot/selfdrive/modeld/jetlink/host_release.json`을 같은 manifest로 갱신합니다.
필요한 경우 구형 Carrot용 NAS stable 채널도 같은 검증된 manifest로 갱신합니다.
CI 산출물은 시험용이며 자동으로 안정 채널에 승격되지 않습니다.

## 상태 확인

- Carrot Web 도구의 eGPU 상태 카드: Jetson IP·온도·상태
- Jetson USB 화면 상단: 온도/내부 오류 경고
- 업데이트 결과: `/opt/carrot-jetlink/updates/status.json`
- 실행 버전: `/opt/carrot-jetlink/current/SOURCE_COMMIT`

P단에서 지도 대신 주행 요약을 표시하는 기존 동작을 유지합니다.
주행 제어 호환성은 대응하는 Carrot 모델 계약과 함께 검증해야 하며, 한 차량의 정차 시험이 다른 차량·주행 조건을 보증하지 않습니다.

## 검증과 라이선스

```sh
python -m pytest --confcutdir=tools/jetlink \
  tools/jetlink/test_hud_media.py tools/jetlink/test_update_host.py \
  tools/jetlink/test_host_health.py tools/jetlink/test_hud.py
```

[LICENSE](LICENSE), [opendbc 라이선스](opendbc_repo/LICENSE), [Jetlink 라이선스](third_party/jetlink/LICENSE)를 보존합니다.
NVIDIA OS/런타임과 모델 파일에는 각각의 배포 조건이 적용됩니다.
