"""Configure a NEW offline image with a separate, prepopulated DATA partition.

Not a live migration tool. Never install this directly on a legacy expanded SD.
"""
import json
from pathlib import Path
import re
import shutil

from finalize_sd_image import write


def configure(root, source, target_dev=None):
  root, source = Path(root).resolve(), Path(source).resolve()
  if root == Path('/') or not (root / 'etc/carrot-jetlink-image.json').is_file():
    raise ValueError('Only an offline Carrot image is supported')
  from initrd_readonly import configure as configure_initrd
  configure_initrd(root)
  from readonly_boot import patch_nv_script
  nv_script = root / 'etc/systemd/nv.sh'
  if nv_script.exists():
    nv_script.write_text(patch_nv_script(nv_script.read_text()))
  # The vendor script derives these from each board serial on every RAM boot.
  # Never ship the build board's cached USB network identity to other devices.
  (root / 'opt/nvidia/l4t-usb-device-mode/mac-addresses').unlink(missing_ok=True)
  destination = root / 'usr/lib/carrot-jetlink-storage'
  destination.mkdir(parents=True, exist_ok=True)
  for name in ('protected_storage.py', 'persistent_state.py', 'wifi_apply.py', 'wifi_protocol.py', 'image_first_boot.py', 'protected_first_boot.py', 'boot_status.py'):
    shutil.copyfile(source / name, destination / name)
    (destination / name).chmod(0o644)
  extlinux = root / 'boot/extlinux/extlinux.conf'
  lines = extlinux.read_text().splitlines()
  found = False
  detected_dev = 'mmcblk0'
  for index, line in enumerate(lines):
    if re.match(r'\s*APPEND\s', line):
      m = re.search(r'root=/dev/(mmcblk0|nvme0n1)p1', line)
      if m:
        detected_dev = m.group(1)
      elif 'root=/dev/' in line:
        raise ValueError('Unexpected boot root')
      if target_dev:
        line = re.sub(r'root=/dev/(mmcblk0|nvme0n1)p1', f'root=/dev/{target_dev}p1', line)
        detected_dev = target_dev
      lines[index] = re.sub(r'\s+rw(?=\s|$)', '', line) + ' ro'
      found = True
  if not found:
    raise ValueError('Missing SD boot command line')
  write(root, '/boot/extlinux/extlinux.conf', '\n'.join(lines) + '\n')

  dev = target_dev or detected_dev
  root_node = f'/dev/{dev}p1'
  data_node = f'/dev/{dev}p17'
  setup_node = f'/dev/{dev}p16'
  efi_node = f'/dev/{dev}p10'

  write(root, '/etc/carrot-jetlink-protected.json', json.dumps(
    dict(format=1, root=root_node, data=data_node, setup=setup_node)) + '\n')
  write(root, '/etc/fstab', f'/dev/root / ext4 ro,noload 0 0\n{efi_node} /boot/efi vfat ro,nofail 0 0\n')
  command = '/usr/bin/python3 /usr/lib/carrot-jetlink-storage/protected_storage.py'
  write(root, '/etc/systemd/system/carrot-protected-storage.service', f'''[Unit]
Description=Read-only system, volatile writes and independent DATA recovery
DefaultDependencies=no
After=systemd-remount-fs.service
Before=local-fs-pre.target systemd-tmpfiles-setup.service systemd-journald.service
Before=carrot-image-setup.service NetworkManager.service ssh.service
[Service]
Type=oneshot
ExecStart={command} boot
RemainAfterExit=yes
TimeoutStartSec=100
[Install]
WantedBy=local-fs-pre.target
''')
  link = root / 'etc/systemd/system/local-fs-pre.target.wants/carrot-protected-storage.service'
  link.parent.mkdir(parents=True, exist_ok=True)
  link.unlink(missing_ok=True)
  link.symlink_to('../carrot-protected-storage.service')
  # Legacy grow expands APP over the remainder of the disk. It must NEVER run
  # on a split image. Fixed DATA size is intentional until a separate grow tool
  # is boot-tested; unused tail space is safer than resizing the wrong partition.
  write(root, '/etc/systemd/system/carrot-image-grow.service', '[Unit]\nDescription=Legacy APP growth disabled on protected layout\nConditionPathExists=/nonexistent-carrot-legacy-layout\n[Service]\nType=oneshot\nExecStart=/bin/true\n')
  write(root, '/etc/systemd/journald.conf.d/carrot-volatile.conf',
        '[Journal]\nStorage=volatile\nRuntimeMaxUse=32M\nRuntimeKeepFree=64M\n')
  write(root, '/etc/security/limits.d/carrot-no-core.conf', '* hard core 0\n')
  write(root, '/etc/systemd/coredump.conf.d/carrot-volatile.conf', '[Coredump]\nStorage=none\nProcessSizeMax=0\n')
  # Machine identity lives in RAM. Never commit it back to immutable APP.
  commit_machine_id = root / 'etc/systemd/system/systemd-machine-id-commit.service'
  commit_machine_id.unlink(missing_ok=True)
  commit_machine_id.symlink_to('/dev/null')
  for name in ('nv', 'nvidia-pva-allowd', 'nv-l4t-usb-device-mode'):
    write(root, f'/etc/systemd/system/{name}.service.d/storage.conf',
          '[Unit]\nRequires=carrot-protected-storage.service\nAfter=carrot-protected-storage.service\n')
  write(root, '/etc/systemd/system/carrot-image-setup.service.d/storage.conf',
        '[Unit]\nRequires=carrot-protected-storage.service\nAfter=carrot-protected-storage.service\n'
        '[Service]\nExecStart=\nExecStart=/usr/bin/python3 /usr/lib/carrot-jetlink-storage/protected_first_boot.py\n')
  for name in ('carrot-jetlink', 'carrot-jetlink-hud', 'carrot-jetlink-update-apply', 'carrot-jetlink-update-stage'):
    write(root, f'/etc/systemd/system/{name}.service.d/storage.conf',
          '[Unit]\nRequires=carrot-protected-storage.service\nAfter=carrot-protected-storage.service\n'
          '[Service]\nEnvironment=PYTHONDONTWRITEBYTECODE=1\n')
  from install_wifi import configure as configure_wifi
  configure_wifi(root)
  write(root, '/etc/systemd/system/carrot-jetlink-wifi.service.d/recovery.conf',
        '[Unit]\nRequires=carrot-protected-storage.service\nAfter=carrot-protected-storage.service carrot-image-setup.service\n'
        '[Service]\nExecStart=\nExecStart=/usr/bin/python3 /usr/lib/carrot-jetlink-storage/wifi_apply.py\n')
  write(root, '/etc/NetworkManager/conf.d/carrot-retry.conf',
        '[connection]\nconnection.autoconnect-retries=0\n')


def main():
  import argparse
  parser = argparse.ArgumentParser(description=__doc__)
  parser.add_argument('--root', type=Path, required=True, help='Mounted offline root directory')
  parser.add_argument('--source', type=Path, default=Path(__file__).parent, help='Source directory of jetlink tools')
  parser.add_argument('--target-device', choices=('mmcblk0', 'nvme0n1'), default=None,
                      help='Target device layout (default: auto-detect from extlinux.conf)')
  args = parser.parse_args()
  configure(args.root, args.source, target_dev=args.target_device)
  print(f'Successfully configured protected storage layout for {args.target_device or "auto-detected device"}')


if __name__ == '__main__':
  main()
