# Carrot Jetson NVMe (nvme0n1) 지원 및 가이드

이 문서는 **Carrot Jetson**을 MicroSD 카드 대신 **NVMe M.2 SSD (`/dev/nvme0n1`)**에서 구동할 수 있도록 리패키징된 변경 사항과 사용 안내를 제공합니다.

---

## 1. 개요 및 주요 변경 사항

기존 원본 `carrot-jetson`은 차량 전원 급차단(Power-Loss) 시 MicroSD 카드의 파일시스템 손상을 방지하기 위해 엄격한 읽기 전용(Read-Only) 및 고정 파티션 보호 메커니즘을 적용하고 있었으며, 이로 인해 `/dev/mmcblk0` 경로가 하드코딩되어 있어 NVMe 장착 시 부팅이 중단되었습니다.

본 리패키징 버전(`carrot-jetson-nvme`)에서는 기존의 전원 차단 방지(Fail-safe) 및 읽기 전용 보호 기능을 그대로 유지하면서, **NVMe(`nvme0n1`)와 SD(`mmcblk0`)를 모두 유연하게 지원**하도록 개선되었습니다.

### 주요 수정 내역

1. **`initrd_readonly.py` (부팅 램디스크 패치)**
   - 부팅 시 루트 블록 디바이스 검사 조건을 확장:
     `[ "${rootdev}" != "mmcblk0p1" ] && [ "${rootdev}" != "nvme0n1p1" ]`
   - 블록 디바이스 읽기 전용 설정 명령을 동적 디바이스명(`/dev/${rootdev}`)으로 변경하여 PID1 진입 전 NVMe 루트 파티션도 정상적으로 `blockdev --setro` 보호 적용.

2. **`protected_storage.py` (보호 스토리지 및 런타임 마운트)**
   - 파티션 구성 검증(`configuration()`)에 NVMe 레이아웃 추가:
     - 루트(APP): `/dev/nvme0n1p1`
     - 설정(SETUP): `/dev/nvme0n1p16`
     - 데이터(DATA): `/dev/nvme0n1p17`
   - `/etc/carrot-jetlink-protected.json`의 구성에 맞춰 NVMe 파티션을 안전하게 검사(`e2fsck`) 후 마운트.

3. **`install_protected.py` & `finalize_sd_image.py` (이미지 구성 도구)**
   - `extlinux.conf`의 커널 파라미터(`root=/dev/nvme0n1p1 ro`) 자동 인식 및 변환 지원.
   - `/etc/fstab`의 EFI 파티션 매핑을 `/dev/nvme0n1p10 /boot/efi`로 알맞게 설정.
   - `--target-device [nvme0n1|mmcblk0]` 옵션 제공.

4. **`protected_first_boot.py` & `image_first_boot.py` (초기 부팅 스크립트)**
   - 고정된 `mmcblk0p16` 대신 `protected.json`에 정의된 `setup` 파티션 또는 감지된 `nvme0n1p16`을 마운트하여 호스트명 및 머신 ID 초기화 진행.

5. **`image_grow_root.py` (파티션 자동 확장)**
   - SD 카드뿐만 아니라 NVMe 장치(`/dev/nvme0n1`)의 APP 파티션 크기 조정을 정상 지원.

6. **Windows 설치기 (`disks.ps1`, `write_sd_windows.ps1`)**
   - 기존의 `USB` 전용 필터링에서 `NVMe` BusType을 안전하게 허용.
   - 단, 실수로 윈도우 OS가 설치된 부팅 드라이브나 시스템 드라이브를 덮어쓰지 않도록 `IsBoot`, `IsSystem`, `IsReadOnly`, 고유 ID 검증 등 안전장치는 엄격하게 유지.

---

## 2. NVMe 파티션 구조

Jetson Orin Nano Super의 GPT 파티션 번호 체계에 따라 다음과 같이 매핑됩니다:

| 파티션 번호 | 디바이스 노드 | 레이블 / 용도 | 비고 |
| :--- | :--- | :--- | :--- |
| **p1** | `/dev/nvme0n1p1` | `APP` | 루트 파일시스템 (Read-Only) |
| **p10** | `/dev/nvme0n1p10` | `ESP` / `boot` | EFI 시스템 부팅 파티션 |
| **p16** | `/dev/nvme0n1p16` | `CARROT_SETUP` | 기기 식별 및 초기 셋업 설정 파티션 (vfat) |
| **p17** | `/dev/nvme0n1p17` | `CARROTDATA` | 런타임, 캐시, Wi-Fi 및 영구 데이터 파티션 (ext4) |

---

## 3. NVMe 부팅 방법

1. **Jetson Orin Nano UEFI 부팅 우선순위 설정**
   - Jetson에 모니터와 키보드를 연결하고 전원을 켠 후 `ESC` 또는 `Del` 키를 눌러 BIOS/UEFI Setup 메뉴로 진입합니다.
   - `Boot Manager` 또는 `Boot Maintenance Manager`에서 NVMe 드라이브를 부팅 순서 1순위로 지정합니다.

2. **이미지 기록 (Flashing)**
   - **방법 A (PC에서 직접 기록):** NVMe SSD를 외장 USB 인클로저에 연결하거나 PC M.2 슬롯에 연결 후 `02_SD카드설치.cmd` (또는 `write_sd_windows.ps1`)를 관리자 권한으로 실행하여 기록합니다.
   - **방법 B (Linux 환경):** `dd` 또는 `bmaptool`을 사용하여 NVMe 드라이브 전체에 이미지를 기록합니다:
     ```bash
     sudo dd if=carrot-jetson-nvme.img of=/dev/nvme0n1 bs=4M status=progress conv=fsync
     ```

3. **기존 SD 이미지를 NVMe용으로 변환할 경우**
   - 이미지를 마운트한 후 `install_protected.py`를 실행하여 부팅 및 스토리지 설정을 NVMe로 전환합니다:
     ```bash
     sudo python3 tools/jetlink/install_protected.py --root /mnt/target_root --target-device nvme0n1
     ```
