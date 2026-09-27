# wrapper-lite QEMU

Run wrapper-lite inside `qemu-system-x86_64`.

## Layout

```text
wrapper-lite-qemu.cpp       # launcher source (repository root)
wrapper-lite-qemu           # launcher binary
qemu/
├── vmlinuz-lite-qemu
├── lite-initramfs.cpio.gz
├── data.img
├── build.sh
├── mkdata.sh
├── init
└── README.md
```

## Build QEMU assets

```bash
apt-get download busybox-static
./qemu/build.sh
```

## Build launcher

```bash
c++ -std=c++11 -O2 -o wrapper-lite-qemu wrapper-lite-qemu.cpp
```

## Run

```bash
./wrapper-lite-qemu --login-stdin
./wrapper-lite-qemu
```

Write the username, password, and any requested 2FA code to standard input. The
launcher rejects `--login user:pass`; credentials are never placed in QEMU
arguments, the kernel command line, or `data.img`.

Launcher options are consumed on the host. Other arguments are forwarded
line-by-line to wrapper-lite inside the guest through QEMU fw_cfg and stored
only in the initramfs.

## Acceleration

- Linux: auto-detect KVM.
- macOS on Apple Silicon: TCG for the x86_64 guest.
- Windows: try WHPX, fall back to TCG.

Force acceleration:

```bash
./wrapper-lite-qemu --accel kvm ...
./wrapper-lite-qemu --accel hvf ...
./wrapper-lite-qemu --accel whpx ...
./wrapper-lite-qemu --accel tcg ...
```

Windows WHPX uses:

```text
-accel whpx,kernel-irqchip=off
-cpu qemu64-v1
```

## Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `HOST_PORT` | `12340` | host port |
| `GUEST_PORT` | `12340` | guest port |
| `MEMORY` | `512` | guest memory in MB |
| `SMP` | `2` | guest CPU count |
| `LITE_QEMU_ACCEL` | auto | force acceleration |
| `QEMU_BIN` | auto | QEMU binary path |

## QEMU lookup order

1. `--qemu-bin` / `QEMU_BIN`
2. `qemu/bin/`
3. `PATH`
