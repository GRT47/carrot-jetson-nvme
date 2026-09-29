#Requires -RunAsAdministrator
param()
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$elevated = [Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $elevated) {
  $arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"{0}"' -f $PSCommandPath))
  $child = Start-Process powershell.exe -Verb RunAs -ArgumentList $arguments -Wait -PassThru
  exit $child.ExitCode
}

try {
  [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
  . "$PSScriptRoot\messages.ps1"
  . "$PSScriptRoot\disks.ps1"

  Write-Host '============================================================' -ForegroundColor Cyan
  Write-Host '  CARROT JETSON  |  NVMe 부팅 즉시 패치 (Instant Patch)' -ForegroundColor Cyan
  Write-Host '  Patch an already-written NVMe SSD for Jetson Orin Nano' -ForegroundColor Cyan
  Write-Host '============================================================' -ForegroundColor Cyan
  Write-Host ''
  Write-InstallerPair '이미 NVMe에 이미지가 기록된 상태에서, 부팅 설정을 5초 만에 NVMe용으로 전환합니다.' 'Converts an already-flashed drive from SD to NVMe boot configuration in seconds.'

  $source = @(Get-Partition -DriveLetter $root.Substring(0,1))
  $sourceDisk = if ($source.Count -ge 1) { [int]$source[0].DiskNumber } else { -1 }

  $choices = @(Get-Disk | Where-Object {
    $null -ne $_ -and
    ($_.BusType -eq 'USB' -or $_.BusType -eq 'NVMe') -and
    -not $_.IsBoot -and -not $_.IsSystem -and -not $_.IsReadOnly -and
    $_.Number -ne $sourceDisk -and
    $_.Size -ge 20GB
  })

  if ($choices.Count -eq 0) {
    throw "패치할 NVMe SSD 드라이브를 찾지 못했습니다. 드라이브 연결을 확인하세요.`nNo eligible NVMe drive found. Check drive connection."
  }

  Write-Host ''
  Write-InstallerPair '패치할 NVMe SSD 드라이브 번호를 입력하세요:' 'Select target NVMe drive:' Yellow
  foreach ($d in $choices) {
    Write-Host ("[{0}] {1} / {2:N1} GB / Bus: {3} / ID: {4}" -f $d.Number, $d.FriendlyName, ($d.Size / 1e9), $d.BusType, $d.SerialNumber)
  }

  $answer = Read-InstallerInput '위 목록의 드라이브 번호 입력' 'Enter the drive number shown above'
  $number = 0
  if (-not [int]::TryParse($answer, [ref]$number)) {
    throw "취소되었습니다.`nCancelled."
  }

  $selected = @($choices | Where-Object Number -eq $number)
  if ($selected.Count -ne 1) {
    throw "목록에 없는 번호입니다.`nNumber not in list."
  }
  $selected = $selected[0]

  Write-Host ''
  Write-Host ("선택한 드라이브: [{0}] {1} ({2:N1} GB)" -f $selected.Number, $selected.FriendlyName, ($selected.Size / 1e9)) -ForegroundColor Green
  Write-InstallerPair '고속 C# 엔진으로 부팅 설정(extlinux, fstab, protected.json)을 nvme0n1로 즉시 패치합니다.' 'Fast native patching boot config for nvme0n1.'

  if (-not ([System.Management.Automation.PSTypeName]'CarrotPatchNative').Type) {
    Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;
public static class CarrotPatchNative {
  [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
  public static extern SafeFileHandle CreateFile(string name, uint access, uint share, IntPtr security, uint creation, uint flags, IntPtr template);
  [DllImport("kernel32.dll", SetLastError=true)]
  static extern bool DeviceIoControl(SafeFileHandle file, uint control, IntPtr input, uint inputBytes, IntPtr output, uint outputBytes, out uint returned, IntPtr overlapped);
  public static SafeFileHandle Open(string path) {
    var handle = CreateFile(path, 0xC0000000, 3, IntPtr.Zero, 3, 0, IntPtr.Zero);
    if (handle.IsInvalid) throw new Win32Exception(Marshal.GetLastWin32Error());
    return handle;
  }
  public static void Control(SafeFileHandle handle, uint code) {
    uint count;
    if (!DeviceIoControl(handle, code, IntPtr.Zero, 0, IntPtr.Zero, 0, out count, IntPtr.Zero))
      throw new Win32Exception(Marshal.GetLastWin32Error());
  }
  public static int ReplaceBytes(byte[] buffer, int count, byte[] target, byte[] replacement) {
    int replaced = 0;
    for (int i = 0; i <= count - 7; i++) {
      if (buffer[i] == target[0] && buffer[i+1] == target[1] && buffer[i+2] == target[2] &&
          buffer[i+3] == target[3] && buffer[i+4] == target[4] && buffer[i+5] == target[5] && buffer[i+6] == target[6]) {
        for (int j = 0; j < 7; j++) buffer[i+j] = replacement[j];
        replaced++;
        i += 6;
      }
    }
    return replaced;
  }
}
'@
  }

  $locks = [System.Collections.Generic.List[System.IDisposable]]::new()
  $device = $null
  try {
    $partitions = Get-Partition -DiskNumber $number
    foreach ($p in $partitions) {
      foreach ($path in $p.AccessPaths) {
        if ($path -like '\\?\Volume{*') {
          try {
            $h = [CarrotPatchNative]::Open($path.TrimEnd('\'))
            $locks.Add($h)
            [CarrotPatchNative]::Control($h, 0x00090018)
            [CarrotPatchNative]::Control($h, 0x00090020)
          } catch {}
        }
      }
    }

    $handle = [CarrotPatchNative]::Open("\\.\PhysicalDrive$number")
    $device = [System.IO.FileStream]::new($handle, [System.IO.FileAccess]::ReadWrite, 16MB, $false)

    $startOffset = [long]1632632832
    $scanLength = [long](3500 * 1024 * 1024)
    $chunkSize = 16 * 1024 * 1024
    $buffer = New-Object byte[] ($chunkSize)
    $targetBytes = [System.Text.Encoding]::ASCII.GetBytes('mmcblk0')
    $replaceBytes = [System.Text.Encoding]::ASCII.GetBytes('nvme0n1')

    $null = $device.Seek($startOffset, [System.IO.SeekOrigin]::Begin)
    $totalScanned = [long]0
    $patchCount = 0

    Write-Host '패치 위치 검색 및 적용 중 (약 3~5초 소요)...' -ForegroundColor Yellow
    while ($totalScanned -lt $scanLength) {
      $currentPos = $startOffset + $totalScanned
      $toRead = [int][Math]::Min([long]$chunkSize, $scanLength - $totalScanned)
      $readCount = $device.Read($buffer, 0, $toRead)
      if ($readCount -le 0) { break }

      $modifiedCount = [CarrotPatchNative]::ReplaceBytes($buffer, $readCount, $targetBytes, $replaceBytes)
      if ($modifiedCount -gt 0) {
        $patchCount += $modifiedCount
        $null = $device.Seek($currentPos, [System.IO.SeekOrigin]::Begin)
        $device.Write($buffer, 0, $readCount)
        $device.Flush($true)
        $null = $device.Seek($currentPos + $readCount, [System.IO.SeekOrigin]::Begin)
      }

      $totalScanned += $readCount
      $percent = [Math]::Min(100, [int]($totalScanned * 100 / $scanLength))
      Write-Progress -Activity 'NVMe 부팅 패치 적용 중' -Status ("[{0}%] 수정된 항목: {1}개" -f $percent, $patchCount) -PercentComplete $percent
    }

    Write-Progress -Activity 'NVMe 부팅 패치 적용 중' -Completed
    $device.Flush($true)
    $device.Dispose(); $device = $null
    foreach ($item in $locks) { $item.Dispose() }; $locks.Clear()

    Update-Disk -Number $number
    Update-HostStorageCache

    Write-Host ''
    Write-Host '============================================================' -ForegroundColor Green
    Write-Host ("  [패치 완료] 총 {0}곳의 부팅 및 시스템 설정을 nvme0n1로 전환했습니다!" -f $patchCount) -ForegroundColor Green
    Write-Host '============================================================' -ForegroundColor Green
    Write-Host ''
    Write-Host '  1. PC에서 NVMe SSD를 안전하게 분리하세요.' -ForegroundColor Cyan
    Write-Host '  2. Jetson Orin Nano의 M.2 NVMe 슬롯에 장착하세요.' -ForegroundColor Cyan
    Write-Host '  3. MicroSD 슬롯은 비워둔 상태로 유지하세요.' -ForegroundColor Cyan
    Write-Host '  4. USB-C 케이블로 콤마(comma)를 연결하고 젯슨 전원을 켜세요!' -ForegroundColor Cyan
    Write-Host ''
  } finally {
    if ($device) { $device.Dispose() }
    foreach ($item in $locks) { $item.Dispose() }
  }
} catch {
  Write-Host ''
  Write-Host ("패치 실패: " + $_.Exception.Message) -ForegroundColor Red
}

$null = Read-InstallerInput 'Enter를 누르면 창을 닫습니다' 'Press Enter to close'
