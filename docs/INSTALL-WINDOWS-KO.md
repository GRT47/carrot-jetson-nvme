# 처음 설치하기: Windows PC → microSD → Carrot Jetson

이 문서는 **Windows에서 프로그램을 설치하고 파일을 내려받는 단계부터** 설명합니다.
이미지와 작은 핫픽스를 한 번 준비하면, 이후 일반 프로그램·모델 업데이트 때마다
SD카드를 빼거나 이미지를 다시 기록할 필요가 없습니다.

> **현재는 시험 배포입니다.** USB-C 수정 자체는 실제 Jetson에 SSH로 설치하여
> 연결·재부팅·정차 시험을 통과했습니다. 아래 **PC 오프라인 패치 방식으로 기록한 카드의
> 실제 첫 부팅은 아직 검증 전**입니다. 소프트웨어 시험 84개와 파일시스템 검사 통과를
> 첫 부팅·다른 차량·주행 검증 완료로 해석하지 마세요.

## 먼저 전체 순서 보기

1. 준비물과 지원 기기를 확인합니다.
2. 7-Zip, balenaEtcher, Python을 PC에 설치합니다.
3. **NAS에서 이미지**, GitHub에서 **핫픽스 ZIP**을 받습니다.
4. 이미지 검사 → 압축 해제 → Etcher로 SD 기록을 합니다.
5. **아직 Jetson에 넣지 말고**, PC에서 핫픽스를 적용합니다.
6. SD를 Jetson에 넣고 콤마와 연결한 뒤 첫 부팅을 확인합니다.

이미 작동 중이며 USB-C 핫픽스도 설치한 사용자는 이 과정을 다시 하지 않습니다.
이미 기록해 두었지만 **한 번도 부팅하지 않은 동일 이미지 카드**가 있다면 8단계부터 진행합니다.

## 1. 준비물과 지원 범위

| 준비물 | 확인할 내용 |
|---|---|
| PC | Windows 10/11 64비트, 관리자 권한. 이 안내는 일반 x64 PC 기준입니다. |
| PC 저장 공간 | 다운로드·압축 해제를 위해 약 50GB 여유 공간을 확보합니다. |
| Jetson | **Jetson Orin Nano Super 개발 키트, P3768 기준 보드**. 구형 Jetson Nano와 다른 제품입니다. |
| microSD | 현재 실물 시험에 사용한 용량은 **128GB**입니다. 중요한 파일은 먼저 별도로 보관합니다. |
| 카드 리더 | **USB로 PC에 연결하는 microSD 리더**. 핫픽스 도구는 USB 디스크만 허용합니다. |
| 전원 | Jetson에 맞는 별도 전원. 콤마와 연결한 USB-C 케이블로 Jetson 전원을 대신하지 않습니다. |
| 연결 케이블 | USB 3.x 데이터 통신을 지원하는 C-to-C 케이블. 충전 전용 케이블은 사용할 수 없습니다. |
| 콤마 | Jetlink와 USB Wi-Fi 전달을 지원하는 Carrot 버전이 설치되어 있어야 합니다. |
| 네트워크 | 콤마에 사용할 Wi-Fi를 먼저 등록합니다. 업데이트를 받으려면 인터넷도 필요합니다. |

현재 이미지 조합은 **L4T 36.4.7 / TensorRT 10.3.0**이며, 포함된 Jetson 런타임은
`f2b22dcf0bd0708658668f7efa2dfb29f81b3bd1`입니다. 콤마 측 USB Wi-Fi 전달은
`ajouatom/openpilot`의 `carrot-jetlink` 코드 `526f81421c`에서 실물 정차 시험으로 확인했습니다.
이 기능은 **2026-09-27 통합 이후 `carrot-wip`**에도 포함됩니다. 별도의 `carrot-jetlink` 브랜치를
새로 설치할 필요는 없습니다. 통합 전의 구형 `carrot-wip`는 지원 대상이 아닙니다.
[통합 기록과 검증 범위](https://github.com/ajouatom/openpilot/blob/carrot-wip/docs/jetson_wip_integration_20260927.md)를
확인하세요. 이전 브랜치의 정차 시험과 통합본의 실물·주행 시험은 별개입니다.
콤마 설정의 소프트웨어/버전 정보에서 브랜치를 확인하고, 지원 여부가 불분명하면
설치 전에 배포자에게 확인하세요. 이 안내는 콤마의 OS·브랜치를 바꾸는 안내가 아닙니다.

다른 Jetson 보드, Orin NX, NVMe 설치, USB 메모리로 Jetson 부팅, 일반 USB 모니터 전체를
지원하는 범용 이미지는 아닙니다. PC의 USB 리더에서 꺼낸 **microSD를 Jetson의 microSD 슬롯에** 넣습니다.

### 처음 산 Jetson의 펌웨어 확인

SD에 기록하는 OS와 Jetson 보드 내부의 부팅 펌웨어(QSPI)는 서로 다릅니다.
이 이미지는 QSPI를 업데이트하지 않습니다. 오래된 출고 펌웨어라면 호환되는
JetPack 6 계열 펌웨어 준비가 먼저 필요할 수 있습니다.
[NVIDIA 공식 초기 준비 안내](https://developer.nvidia.com/embedded/learn/get-started-jetson-orin-nano-devkit)와
[펌웨어 업데이트 안내](https://docs.nvidia.com/jetson/orin-nano-devkit/user-guide/update_firmware.html)를 참고하세요.
NVIDIA 안내의 최신 OS를 무조건 덮어쓰는 것이 아니라, **이 이미지의 L4T 36.4.7과 맞는 조합인지**
확인해야 합니다. 펌웨어가 맞지 않아 부팅하지 못하는 경우에는 같은 SD 이미지를 반복해서 만들어도 해결되지 않습니다.

## 2. PC에 필요한 프로그램 설치

아래 공식 사이트에서 받습니다. 프로그램 자체를 NAS나 이 저장소에서 재배포하지 않습니다.

| 프로그램 | 공식 다운로드 | 용도 |
|---|---|---|
| 7-Zip | [7-zip.org](https://www.7-zip.org/) | `.img.zst` 압축 해제. 오래된 버전 대신 현재 Windows x64 버전을 설치합니다. |
| balenaEtcher | [etcher.balena.io](https://etcher.balena.io/) | 이미지 전체를 SD에 기록하고 검사합니다. Windows x64용을 선택합니다. |
| Python Install Manager | [Python Windows 다운로드](https://www.python.org/downloads/windows/) | 작은 핫픽스 도구를 실행할 Python을 준비합니다. |

7-Zip과 Etcher는 설치 파일을 실행해 설치를 마칩니다.
Python은 공식 페이지의 **Python Install Manager**를 설치합니다. MSIX 파일을 받은 경우
더블클릭하여 `설치`를 누릅니다. Microsoft Store의 공식 Python Install Manager를 사용해도 됩니다.

설치 후 기존 터미널 창은 닫고 다시 여세요. 시작 메뉴에서 `PowerShell`을 검색하여 실행한 뒤,
아래 두 줄을 한 줄씩 입력하고 Enter를 누릅니다.

```powershell
pymanager install 3.14
py -V:3.14 --version
```

`Python 3.14.x`가 표시되면 준비됐습니다. 이미 Python 3.10 이상을 사용 중이라면
기존 Python으로도 핫픽스를 실행할 수 있습니다. 아래 예시는 설치한 3.14를 명시하여 사용합니다.
핫픽스 실행에 별도 `pip install` 명령은 필요 없습니다.

명령을 찾을 수 없다고 나오면 [Python 공식 Windows 문제 해결](https://docs.python.org/3/using/windows.html#troubleshooting)을
확인하세요. 기존 `py` 실행기와 충돌하는 경우가 있어 설치 명령에는 `pymanager`를 사용합니다.

## 3. 작업 폴더 만들기와 PowerShell 사용법

명령 상자에서 **명령만** 복사합니다. `PS C:\...>` 같은 프롬프트나 예상 출력은 입력하지 않습니다.
아래 단계의 변수는 같은 PowerShell 창에서 유지됩니다. 창을 닫았다면 필요한 변수 설정부터 다시 실행합니다.

```powershell
$ErrorActionPreference = 'Stop'
$work = Join-Path $env:USERPROFILE 'Downloads\Carrot-Jetson'
New-Item -ItemType Directory -Path $work -Force | Out-Null
Set-Location -LiteralPath $work
```

이제 파일을 저장할 폴더는 사용자 계정의 **다운로드 → Carrot-Jetson**입니다.
예를 들어 사용자명이 `Kim`이면 `C:\Users\Kim\Downloads\Carrot-Jetson`입니다.
오류가 빨간 글씨로 표시되면 다음 단계로 넘어가지 말고 해당 오류부터 확인합니다.

파일 탐색기에서는 `보기 → 표시 → 파일 확장명`을 켜 두세요.
Windows 버전에 따라 `보기` 탭의 `파일 확장명` 체크 항목입니다.

## 4. NAS 이미지와 GitHub 핫픽스 다운로드

| 파일 | 다운로드 | 설명 |
|---|---|---|
| `carrot-jetson.img.zst` | [NAS 이미지 받기](https://upload.shind0.synology.me/downloads/jetson/v0.2.0-preview/carrot-jetson.img.zst) | **8,249,905,714바이트**, 약 8.25GB. 실제 설치 이미지의 압축 파일입니다. |
| `release.json` | [NAS 버전 정보](https://upload.shind0.synology.me/downloads/jetson/v0.2.0-preview/release.json) | 이미지 버전·크기·검증 범위입니다. |
| `SHA256SUMS` | [NAS 검사값](https://upload.shind0.synology.me/downloads/jetson/v0.2.0-preview/SHA256SUMS) | 다운로드와 압축 해제 결과를 확인하는 SHA256입니다. |
| `carrot-jetson-offline-usbc-v1.zip` | [GitHub PC 핫픽스 ZIP](https://github.com/ajouatom/carrot-jetson/releases/download/v0.2.2-offline-usbc-preview/carrot-jetson-offline-usbc-v1.zip) | 첫 부팅 전에 적용하는 작은 수정 패키지입니다. |

브라우저로 받을 때는 위에서 만든 `Carrot-Jetson` 폴더에 저장합니다.
GitHub의 `Code → Download ZIP` 또는 `Source code (zip)`은 소스 코드입니다.
**그 파일을 SD에 기록하지 않습니다.** GitHub의 `manifest.json`도 설치 이미지가 아닙니다.
이미지는 NAS, PC 핫픽스는 위 링크의 이름이 정확히 일치하는 ZIP입니다.

### 이미지 다운로드가 끊기는 경우: 이어받기 명령

브라우저 대신 다음 명령으로 받을 수 있습니다. 같은 파일을 여러 방법으로 동시에 받지 마세요.
첫 다운로드에도 사용할 수 있고, 중간에 끊겼을 때 같은 명령을 다시 실행해 이어받을 수 있습니다.

```powershell
curl.exe --fail --location --retry 5 --continue-at - --output "$work\carrot-jetson.img.zst" "https://upload.shind0.synology.me/downloads/jetson/v0.2.0-preview/carrot-jetson.img.zst"
```

이미 다운로드가 끝난 파일에 이어받기를 실행하면 범위 오류가 날 수 있습니다.
그 경우 먼저 아래 해시 검사를 하세요. 해시가 같으면 다시 받을 필요가 없습니다.

## 5. 다운로드가 정상인지 검사

아래 명령을 실행합니다. 큰 파일을 읽으므로 잠시 기다려야 합니다.

```powershell
$imageZst = Join-Path $work 'carrot-jetson.img.zst'
$expectedZst = '61fce013d1fb9db548084ca4d2e9a3ea9d697717b1470725f0fec39830fc3285'
if ((Get-FileHash -LiteralPath $imageZst -Algorithm SHA256).Hash -ne $expectedZst) {
  throw '이미지 다운로드 검사 실패. SD 기록을 진행하지 마세요.'
}
'이미지 다운로드 검사 통과'
```

성공 기준은 마지막의 **`이미지 다운로드 검사 통과`**입니다.
다른 이름의 파일이나 다른 버전 이미지는 이번 핫픽스에 사용할 수 없습니다.

## 6. 이미지 압축 해제

1. 파일 탐색기에서 `carrot-jetson.img.zst`를 찾습니다.
2. 마우스 오른쪽 버튼을 누릅니다. Windows 11에서는 `더 많은 옵션 표시`가 필요할 수 있습니다.
3. `7-Zip → 여기에 풀기`를 선택합니다.
4. 같은 폴더에 **`carrot-jetson.img`**가 생길 때까지 기다립니다.

명령으로 풀려면 기본 위치에 설치된 7-Zip을 다음과 같이 실행할 수도 있습니다.
GUI 압축 해제를 했다면 이 명령은 반복하지 않습니다.

```powershell
& "$env:ProgramFiles\7-Zip\7z.exe" x "$work\carrot-jetson.img.zst" "-o$work"
if ($LASTEXITCODE -ne 0) { throw '압축 해제 실패' }
```

압축을 푼 `.img` 파일은 **25,769,803,776바이트(24GiB)**입니다.
이 파일을 다시 압축 해제하거나 내부 Linux 파일을 탐색기에서 수정하지 않습니다.

```powershell
$image = Join-Path $work 'carrot-jetson.img'
$expectedImage = '5a1e7a3ba6156c621d8a01412f062b6c16ecb8ef2274b82b6acdaadf4b19a516'
if ((Get-Item -LiteralPath $image).Length -ne 25769803776) { throw '이미지 크기 불일치' }
if ((Get-FileHash -LiteralPath $image -Algorithm SHA256).Hash -ne $expectedImage) {
  throw '압축 해제 이미지 검사 실패'
}
'압축 해제 이미지 검사 통과'
```

## 7. Etcher로 SD카드 기록

**여기서 선택한 카드의 기존 내용은 전부 지워집니다.** 다른 USB 저장장치는 분리하고
기록할 microSD 리더만 연결하면 선택 실수를 줄일 수 있습니다.

1. microSD를 USB 카드 리더에 넣고 PC에 연결합니다.
2. balenaEtcher를 실행합니다.
3. **`Flash from file`**을 누릅니다.
4. 위에서 확인한 **`carrot-jetson.img`**를 선택합니다.
5. **`Select target`**을 누릅니다.
6. 카드 리더 이름과 용량을 보고 **기록할 microSD 하나만** 선택합니다. PC의 SSD/HDD는 선택하지 않습니다.
7. **`Flash!`**를 누릅니다. Windows 관리자 권한 창이 나오면 선택한 장치를 다시 확인하고 허용합니다.
8. 기록과 **검증(Validating)**이 모두 끝나 성공 표시가 나올 때까지 기다립니다.

`.img` 파일을 SD의 드라이브에 드래그해서 복사하는 것은 설치가 아닙니다.
Etcher가 전체 이미지의 파티션과 파일시스템을 기록해야 합니다.
Etcher 사용 전에 SD를 별도로 포맷할 필요는 없습니다.

완료 후 Windows가 `사용하려면 포맷해야 합니다`라고 물으면 **취소**합니다.
Linux 파티션을 Windows가 읽지 못해 나오는 창일 수 있습니다.
작은 `CARROTSETUP` 드라이브만 보이거나 64MB 정도만 보이는 것도 전체 카드 용량이 줄었다는 뜻은 아닙니다.

Etcher가 카드를 자동으로 꺼냈다면 리더를 PC에서 뺐다가 다시 꽂습니다.
**아직 Jetson에 넣어 부팅하지 마세요. 다음 핫픽스까지 PC에서 끝냅니다.**

## 8. 핫픽스 ZIP 검사와 압축 해제

이후에는 관리자 PowerShell이 필요합니다.
시작 메뉴 → `Windows PowerShell` 검색 → 마우스 오른쪽 → **관리자 권한으로 실행**합니다.
제목에 `관리자`가 있는지 확인하고 아래를 실행합니다. 새 창이므로 작업 폴더 변수도 다시 설정합니다.

```powershell
$ErrorActionPreference = 'Stop'
$work = Join-Path $env:USERPROFILE 'Downloads\Carrot-Jetson'
$hotfixZip = Join-Path $work 'carrot-jetson-offline-usbc-v1.zip'
$expectedHotfix = '1909fc45f667c6365c907cedb6e81442fa61e1e31db91c4e623849599f0bcf5e'
if ((Get-FileHash -LiteralPath $hotfixZip -Algorithm SHA256).Hash -ne $expectedHotfix) {
  throw '핫픽스 ZIP 검사 실패'
}
Unblock-File -LiteralPath $hotfixZip
$hotfix = Join-Path $work 'Offline-Hotfix'
Expand-Archive -LiteralPath $hotfixZip -DestinationPath $hotfix -Force
Get-ChildItem -LiteralPath $hotfix
```

파일 목록에 `apply_offline_hotfix_windows.ps1`, `offline_hotfix.py`, `offline-usbc.json`이
함께 있어야 합니다. ZIP 안에서 직접 실행하지 않습니다. ZIP을 `CARROTSETUP`에 복사만 해도 적용되지 않습니다.

## 9. 카드 번호 확인

관리자 PowerShell에서 아래 명령을 실행합니다.

```powershell
Get-Disk | Where-Object { $_.BusType -eq 'USB' -and $_.Size -gt 0 } |
  Select-Object Number, FriendlyName, SerialNumber,
    @{Name='SizeGiB';Expression={[math]::Round($_.Size / 1GB, 1)}}, IsBoot, IsSystem |
  Format-Table -AutoSize
```

예를 들어 `Number=5`, 이름이 카드 리더, 크기가 약 `119.4`이면 128GB 카드일 수 있습니다.
**5는 예시일 뿐입니다. 자신의 화면에서 확인한 번호를 사용하세요.** `F:` 같은 드라이브 문자와 다릅니다.
확실하지 않으면 리더를 빼고 목록을 다시 확인한 뒤, 꽂았을 때 새로 나타난 항목을 찾습니다.
다시 꽂으면 번호가 달라질 수 있습니다.

아래 명령은 질문이 나오면 카드 번호를 입력받고, 해당 카드의 일련번호와 바이트 크기를 자동으로 읽습니다.

```powershell
$cardNumber = [int](Read-Host '방금 확인한 microSD 디스크 Number를 입력하세요')
$card = Get-Disk -Number $cardNumber
if ($card.IsBoot -or $card.IsSystem -or $card.IsReadOnly -or $card.BusType -ne 'USB' -or $card.Size -le 0) {
  throw '기록할 수 있는 USB 카드가 아닙니다'
}
if ([string]::IsNullOrWhiteSpace($card.SerialNumber)) {
  throw '리더 일련번호를 확인할 수 없습니다. 다른 USB 카드 리더를 사용하세요.'
}
$card | Format-List Number, FriendlyName, SerialNumber, Size, BusType, IsBoot, IsSystem
```

출력된 이름·크기가 자신의 카드와 일치하는지 확인합니다. 이후 기록이 끝날 때까지 리더를 뽑지 않습니다.

## 10. PC에서 핫픽스 적용

먼저 실제 Python 실행 파일 경로를 읽습니다. 설치 경로를 직접 추측할 필요가 없습니다.

```powershell
$pythonExe = (& py -V:3.14 -c 'import sys; print(sys.executable)').Trim()
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $pythonExe)) { throw 'Python 실행 파일을 확인할 수 없습니다' }
& $pythonExe --version
```

기존 Python 3.10 이상을 사용하는 경우에는 첫 줄의 `-V:3.14`를 해당 버전으로 바꿉니다.
이제 아래 블록 전체를 복사하여 실행합니다. 마지막 확인 질문에 `APPLY`를 입력해야 기록을 시작합니다.

```powershell
if ((Read-Host "디스크 $cardNumber 에 핫픽스를 적용하려면 APPLY를 입력하세요") -cne 'APPLY') {
  throw '사용자가 취소했습니다. 기록하지 않았습니다.'
}
$patchArgs = @{
  DiskNumber = $cardNumber
  SerialNumber = $card.SerialNumber.Trim()
  DiskBytes = [long]$card.Size
  Python = $pythonExe
  ManifestSha256 = '1ba794698dd136e6fc089891a5711ca4fcbba826335dc960e4f2b41465ea539a'
  Manifest = Join-Path $hotfix 'offline-usbc.json'
  Log = Join-Path $work ('offline-hotfix-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.log')
}
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
& (Join-Path $hotfix 'apply_offline_hotfix_windows.ps1') @patchArgs
```

실행 정책 변경은 **현재 창에만** 적용됩니다. PC 전체 정책을 바꾸는 명령은 아닙니다.
회사 PC의 관리 정책 때문에 거부되면 정책을 우회하지 말고 사용할 수 있는 개인 PC나 관리자 지원을 이용하세요.

도구가 먼저 Linux 파티션 약 24GB를 읽어 원본 여부를 검사하므로, 실제 수정량이 작아도 몇 분 걸릴 수 있습니다.
`CHECK ... / ...` 숫자가 증가하면 검사 중입니다. 케이블을 빼거나 창을 닫지 마세요.

성공하면 아래와 같은 문구가 표시됩니다. **이 출력은 입력하는 명령이 아닙니다.**

```text
APPLIED_AND_READ_BACK 5632 bytes
OFFLINE_HOTFIX_COMPLETE (first boot installation still needs verification)
```

이미 적용한 미부팅 카드라면 첫 줄 대신 `ALREADY_APPLIED`가 나올 수 있습니다.
로그와 같은 이름의 `.success` 파일도 만들어집니다. 실제 로그 경로는 다음 명령으로 확인합니다.

```powershell
$patchArgs.Log
Test-Path -LiteralPath ($patchArgs.Log + '.success')
```

마지막 값이 `True`인지 확인합니다. `.failed`나 오류가 있으면 완료로 판단하지 않습니다.
이 성공은 **PC에서의 기록·재읽기 검증 성공**이며 Jetson 첫 부팅 성공을 뜻하지는 않습니다.

카드를 이미 Jetson에서 부팅했다면 루트 확장과 설정 변경 때문에 이 도구는 거부합니다.
사용 중인 카드를 초기화해서 이 절차를 강제로 반복하지 말고
[기존 장치용 USB-C 설치 안내](../tools/jetlink/USB-C-HOTFIX.md)를 이용합니다.

## 11. Jetson에 넣고 첫 부팅

1. Etcher와 SD 폴더를 열어 둔 탐색기 창을 닫습니다.
2. Windows 작업 표시줄의 **하드웨어 안전하게 제거**로 카드 리더를 꺼냅니다.
3. Jetson의 전원이 꺼져 있는 상태에서 microSD를 Jetson 슬롯에 넣습니다.
4. **Jetson USB-C ↔ 콤마 USB-C**를 데이터 케이블로 연결합니다.
5. 사용하는 호환 USB 계기판이 있다면 지정된 Jetson USB-A 포트에 연결합니다. 모든 USB 모니터를 지원한다는 뜻은 아닙니다.
6. Jetson에 별도 전원을 연결하고 콤마도 켭니다. 첫 확인은 주차·비활성 상태에서 합니다.
7. 첫 부팅 준비가 끝날 때까지 수 분 기다립니다. 준비 중에는 SD를 빼거나 전원을 반복해서 끄지 않습니다.

부팅 중 카드 용량 확장, 기기 고유 정보 생성, USB-C 정책 설치가 진행됩니다.
기존 이미지의 사전 준비된 모델을 사용하므로 정상 첫 부팅을 위해 Git 소스나 모델을
직접 내려받아 설치하는 과정은 필요하지 않습니다.

USB가 연결되면 콤마에 저장된 Wi-Fi 정보를 받아 Jetson이 연결합니다.
**SD에 SSID·비밀번호를 직접 적는 것이 기본 절차가 아닙니다.**
Wi-Fi가 바뀌면 콤마의 설정을 변경합니다. Jetson은 주기적으로 반영하므로 SD를 꺼낼 필요가 없습니다.

화면 진단에 일반 모니터를 쓰려면 보드의 DisplayPort를 확인하세요.
Jetson USB-C는 데이터 포트이며 DisplayPort 출력이나 Jetson 전원 입력을 대신하지 않습니다.
[NVIDIA 포트 위치와 용도](https://docs.nvidia.com/jetson/orin-nano-devkit/user-guide/hardware_layout.html)를 참고하세요.

## 12. 어디서 정상 동작을 확인하나요?

1. 휴대폰/PC와 콤마를 같은 로컬 네트워크에 연결합니다.
2. 콤마의 네트워크 설정에서 **콤마 IP**를 확인합니다.
3. 브라우저 주소창에 `http://콤마IP:7000`을 입력합니다.
   예를 들어 IP가 `192.168.0.25`라면 `http://192.168.0.25:7000`입니다. 예시 IP를 그대로 쓰지 않습니다.
4. **Carrot Web → 도구 → eGPU 상태**에서 Jetson 연결 상태, IP, 온도와 오류 내용을 확인합니다.

Jetson 상태를 보러 들어가는 웹 주소의 IP는 **콤마 IP**이고,
그 안에 표시되는 **Jetson IP**는 Jetson에 관리 접속할 때 사용합니다.

| 확인할 것 | 해석 |
|---|---|
| Jetson 연결·모델 상태 | 단순히 LED가 켜진 것과 추론이 정상 동작하는 것은 다릅니다. 대기/오류 이유를 함께 확인합니다. |
| Jetson IP | Wi-Fi 등 네트워크 인터페이스 주소입니다. USB가 연결됐다는 이유만으로 인터넷까지 연결된 것은 아닙니다. |
| Jetson 온도 | 최신 값이 보이는지 확인합니다. 값이 없으면 온도가 0도라는 뜻이 아닙니다. |
| 화면 상단 경고 | 읽을 수 있는 내부 오류나 온도 경고가 표시되는지 확인합니다. |
| 외부 네비 지도 | **P단에서는 주행 요약을 표시하는 현재 동작이 의도된 것**입니다. P단에서 지도 대신 요약이 보인다는 이유만으로 설치 실패로 판단하지 않습니다. |

연결이 정상인 경우에도 다른 기기·주행 조건까지 검증됐다는 뜻은 아닙니다.
네비 스트리밍 설정과 실제 화면 호환성은 별도 확인 대상입니다.

## 13. 이후 업데이트와 다른 콤마에 연결하기

일반 업데이트의 순서는 다음과 같습니다.

1. 배포자가 시험한 프로그램·모델을 서명하여 NAS에 게시합니다.
2. 지원 Carrot가 대응하는 Jetson 릴리스를 지정합니다.
3. Jetson이 콤마의 **offroad 상태**를 확인하고 파일을 내려받아 검증합니다.
4. 다음 정상 부팅 때 적용 전 추론 검사를 하고, 통과하면 새 버전을 사용합니다.
5. 적용 전 검사에 실패하면 기존 버전을 유지합니다.

자동 확인은 부팅 약 2분 후, 이후 약 15분 간격입니다. **P단 정차와 offroad는 다릅니다.**
콤마와 Jetson의 전원·네트워크가 유지되어야 합니다. 시동을 끄자마자 Jetson 전원이 함께
차단되는 구성에서는 자동 다운로드 시간이 부족할 수 있습니다.
GitHub에 커밋이 올라왔다고 즉시 설치되는 것도 아닙니다. 시험·서명·릴리스 지정 후 반영됩니다.
설치 폴더에서 사용자가 직접 `git pull`하거나 `pip install --upgrade`할 필요는 없습니다.

지원되는 다른 콤마에 연결하면 그 콤마의 Wi-Fi 정보를 받아 이전에 자동으로 받은 프로필을 교체합니다.
소프트웨어의 이 동작과 다른 실물 콤마에서의 전체 검증은 구분합니다.
개인 정보가 들어간 사용 중 SD카드를 복제해서 다른 사람에게 배포하지 않습니다.
새 사용자에게는 NAS의 개인정보 없는 원본과 이 안내를 제공합니다.

JetPack, TensorRT, 커널, QSPI 변경은 일반 프로그램 업데이트와 다릅니다.
그런 변경이 필요한 릴리스는 별도의 호환성·OS 유지보수 안내를 따라야 합니다.

## 14. 자주 겪는 문제

| 증상/문구 | 할 일 |
|---|---|
| NAS 다운로드가 404/연결 실패 | 릴리스 페이지의 다운로드 공지를 확인합니다. `Source code.zip`이나 다른 모델 파일로 대체하지 않습니다. |
| 7-Zip이 `.zst`를 열지 못함 | 최신 공식 7-Zip으로 업데이트하고 압축 파일 SHA256부터 확인합니다. |
| PC 공간 부족 | 압축본 약 8.25GB와 압축 해제본 약 25.77GB가 동시에 필요합니다. SD가 아니라 PC 저장 공간을 확인합니다. |
| Windows가 SD를 포맷하라고 함 | 취소합니다. 이미지 기록 후 Linux 파티션이 Windows에서 보이지 않을 수 있습니다. |
| SD가 64MB로만 보임 | `CARROTSETUP`만 보이는 경우입니다. 임의로 파티션을 삭제하거나 포맷하지 않습니다. |
| Etcher 기록/검증 실패 | 실패 카드를 바로 부팅하지 않습니다. 이미지 해시, 카드 리더·카드·USB 포트를 확인한 뒤 다시 기록합니다. |
| `Get-Disk` 접근 거부 / 관리자 필요 | PowerShell을 관리자 권한으로 다시 엽니다. 새 창에서는 작업 폴더·카드 변수도 다시 설정합니다. |
| `Python`/`py` 명령을 못 찾음 | Python Install Manager 설치 후 터미널을 다시 열고 `py -V:3.14 --version`부터 확인합니다. |
| 실행 정책 때문에 `.ps1` 차단 | ZIP 검사 후 압축 해제했는지, 10단계의 현재 창 실행 정책 명령을 실행했는지 확인합니다. 조직 관리 정책은 별도입니다. |
| `Release manifest checksum mismatch` | 다른 버전 파일이 섞였는지 ZIP 검사부터 다시 확인합니다. 검사값을 임의로 바꾸지 않습니다. |
| `USB disk identity/capacity/system-disk guard failed` | 카드 번호가 바뀌었거나 다른 디스크/내장 리더를 골랐을 수 있습니다. 9단계부터 다시 확인합니다. |
| `Partition identity differs...` | 다른 이미지이거나 기록이 불완전합니다. 원본 이미지와 Etcher 결과를 확인합니다. |
| `Not the pristine supported root filesystem...` | 이미 부팅한 카드, 다른 버전, 손상된 기록일 수 있습니다. 사용 중 카드라면 온라인 설치 경로를 사용합니다. |
| `CHECK` 숫자가 천천히 증가 | 전체 파티션을 읽어 검사하는 중입니다. 쓰기 용량이 작아도 검사는 시간이 걸립니다. |
| 적용 중 리더가 빠짐 | 같은 패키지로 다시 실행하면 검증 후 수정 영역을 복구할 수 있습니다. 다른 영역 손상까지 검사 우회로 복구하지는 않습니다. |
| Jetson 전원은 켜지나 연결이 빨간색 | 핫픽스 `.success`, 지원 Carrot, 별도 전원, 데이터 케이블과 연결 포트를 순서대로 확인합니다. 오류 문구를 기록합니다. |
| Jetson IP가 없음 | 콤마 Wi-Fi 설정, USB 연결 상태, Wi-Fi 접속 가능 여부를 확인합니다. USB 케이블이 콤마 인터넷을 공유하는 기능은 아닙니다. |
| 로그인 비밀번호를 모름 | 공통 초기 비밀번호가 없습니다. 아래 공개키 등록을 한 경우에만 그 키로 SSH 접속합니다. |
| P단에서 지도 대신 요약 | 현재 의도된 표시입니다. 지도 확인만을 위해 차량을 움직일 필요는 없습니다. |
| 업데이트가 바로 반영되지 않음 | 대응 릴리스 지정, offroad, 전원·인터넷 유지, 확인 주기와 다음 부팅 조건을 확인합니다. |

## 15. 선택 사항: SSH 관리 접속 준비

**일반 Wi-Fi 자동 연결과 추론에는 필요 없습니다.** 배포자 도움을 받아 점검하거나
직접 관리할 계획이 있는 사람만 진행합니다. 첫 부팅 전, PC 핫픽스 적용을 마친 뒤에 설정합니다.
다른 사람의 키를 공용 이미지에 넣지 않습니다.

Windows의 OpenSSH 클라이언트가 필요합니다. `ssh -V`가 안 되면 Windows 설정의
선택적 기능에서 **OpenSSH 클라이언트**를 설치합니다.

```powershell
$keyDir = Join-Path $env:USERPROFILE '.ssh'
New-Item -ItemType Directory -Path $keyDir -Force | Out-Null
$key = Join-Path $keyDir 'carrot_jetson_ed25519'
if (-not (Test-Path -LiteralPath $key)) {
  ssh-keygen -t ed25519 -f $key -C 'carrot-jetson'
  if ($LASTEXITCODE -ne 0) { throw 'SSH 키 생성 실패' }
}
Get-Content -LiteralPath ($key + '.pub')
```

키를 보호할 암호(passphrase)를 물으면 정해서 입력합니다. 이미 같은 이름의 키가 있으면
위 명령은 덮어쓰지 않습니다. `.pub`로 끝나는 파일은 **공개키**, 확장자 없는 파일은
**개인키**입니다. 개인키는 SD·NAS·GitHub에 복사하지 않습니다.

탐색기에서 SD의 작은 `CARROTSETUP` 드라이브를 확인합니다.
아래에서는 앞서 선택한 `$cardNumber`의 **16번 파티션**을 사용하며 다른 USB는 선택하지 않습니다.
탐색기에서 해당 드라이브를 볼 수 없거나 아래 검사가 실패하면 임의의 드라이브 문자를 넣지 마세요.

```powershell
$setupPartition = Get-Partition -DiskNumber $cardNumber -PartitionNumber 16
if ($setupPartition.Size -ne 64MB -or -not $setupPartition.DriveLetter) { throw 'CARROTSETUP 파티션을 확인하세요' }
$setupVolume = $setupPartition | Get-Volume
if ($setupVolume.FileSystemLabel -ne 'CARROTSETUP') { throw '다른 파티션입니다' }
$setupFile = '{0}:\setup.json' -f $setupPartition.DriveLetter
$publicKey = (Get-Content -LiteralPath ($key + '.pub') -Raw).Trim()
$setupJson = @{ssh_public_keys=@($publicKey)} | ConvertTo-Json -Depth 3
[IO.File]::WriteAllText($setupFile, $setupJson, [Text.UTF8Encoding]::new($false))
'SSH 공개키 설정 저장 완료'
```

`setup.json.txt`가 아니라 `setup.json`이어야 합니다. 위 명령은 UTF-8 BOM 없이 정확한 이름으로 저장합니다.
`setup.example.json`의 예시 문자열을 수정하지 않은 채 복사하면 설정 검증에 실패할 수 있습니다.
Wi-Fi는 콤마에서 받으므로 이 설정에는 비밀번호를 넣지 않습니다.

안전하게 제거하고 첫 부팅한 뒤 Carrot Web에서 확인한 **Jetson IP**로 접속합니다.

```powershell
$jetsonIp = Read-Host 'Carrot Web에 표시된 Jetson IP를 입력하세요'
ssh -i "$env:USERPROFILE\.ssh\carrot_jetson_ed25519" "jetlink@$jetsonIp"
```

첫 연결에서는 서버 장치키 확인이 나옵니다. 자신의 Jetson 주소인지 확인하고 진행합니다.
재설치 후 장치키 변경 경고가 뜨면 새 SD 부팅 여부와 주소를 확인하세요.
경고가 났다고 무조건 기존 신뢰 키를 지우거나 검사를 끄지는 않습니다.

아래는 **SSH로 접속한 Jetson 터미널 안에서** 실행하는 읽기 전용 확인 명령입니다.
PC의 PowerShell에 그대로 입력하는 명령이 아닙니다.

```sh
systemctl is-active carrot-jetlink-usbc-host.service carrot-jetlink.service carrot-jetlink-wifi.service
systemctl is-active carrot-jetlink-hud.service carrot-jetlink-update-stage.timer
cat /sys/class/usb_role/usb2-0-role-switch/role
lsusb -t
cat /opt/carrot-jetlink/current/SOURCE_COMMIT
cat /opt/carrot-jetlink/updates/status.json
```

정책 역할은 `host`, 콤마 연결 항목은 `5000M`인지 확인합니다. 목록의 모든 USB가 5000M이어야
하는 것은 아닙니다. 오류 문의에는 설치 이미지 버전, PC 핫픽스 로그, eGPU 상태와 위 결과를 함께 제공합니다.
Wi-Fi 비밀번호·개인키·개인정보가 있는 전체 설정 파일은 공개 게시물에 첨부하지 않습니다.

## 관련 안내와 출처

- [프로젝트 첫 화면](../README.md), [PC 핫픽스 상세와 검증 범위](../tools/jetlink/OFFLINE-HOTFIX.md)
- [PC 핫픽스 시험 릴리스](https://github.com/ajouatom/carrot-jetson/releases/tag/v0.2.2-offline-usbc-preview)
- [84개 시험 결과](https://github.com/ajouatom/carrot-jetson/actions/runs/36310224231)
- [Etcher 공식 사용 안내](https://etcher-docs.balena.io/), [Etcher 포맷/검증 설명](https://etcher.balena.io/)
- [7-Zip 변경 이력: ZSTD 지원](https://www.7-zip.org/history.txt)
- [Python 공식 Windows 설치와 버전 선택](https://docs.python.org/3/using/windows.html)

이 안내의 이미지 해시와 핫픽스 해시는 위에 명시된 **특정 시험 릴리스**의 값입니다.
새 릴리스에서는 해당 릴리스의 안내를 사용합니다. 서로 다른 버전의 파일과 검사값을 섞지 않습니다.
