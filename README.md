# ALT Linux Server ISO to Docker Patch Images

Automated build of clean, lightweight Docker images for official ALT Linux Server releases (branches `p11`, `p10`) built directly from official distribution ISOs.

---

## ❓ Problem & Solution

Official ALT Linux Server installation media is distributed primarily as large installation ISO images (4.2+ GB).

The `altlinux-iso-docker-patch` pipeline automates:
1. Downloading official ALT Linux Server ISOs directly from official BaseALT distribution mirrors.
2. Mounting the installation ISO and extracting the clean root filesystem from the live SquashFS.
3. Performing deep optimization to strip non-container hardware drivers, kernel modules, firmware, and GUI installer components.
4. Importing the clean container rootfs into Docker and publishing tagged images to **Docker Hub** and **GitHub Packages (GHCR)**.

---

## ✂️ What is Stripped from the Rootfs (Size Optimization)

The build script strips non-container bloat, reducing the uncompressed Docker image from **~1.6 GB** down to **~760 MB** (saving over **850 MB** / **>50%** per image):

| Component / Path | What it is | Why it is safe to remove in Docker | Disk Space Saved |
|---|---|---|---|
| **Hardware Firmware** (`/usr/lib/firmware`, `/lib/firmware`) | Wi-Fi, Ethernet (Mellanox/Intel), GPU drivers | Containers share host hardware; firmware is never loaded. | **~390 MB** |
| **Linux Kernel & Modules** (`/usr/lib/modules`, `/lib/modules`, `/boot/vmlinuz*`) | Linux kernel binaries and kernel drivers | Containers execute on the host kernel; internal modules are unused. | **~140 MB** |
| **GPU Drivers & Mesa/LLVM** (`/usr/lib/llvm*`, `gallium-pipe`, `dri`) | 3D graphics compiler and display drivers | Not required for headless server containers. | **~240 MB** |
| **Alterator GUI Installer** (`/usr/share/qt6`, `/usr/share/alterator*`) | Installer GUI wizard and Qt6 runtime | Distribution installation is already complete. | **~40 MB** |
| **Documentation & Manuals** (`/usr/share/{doc,man,info}`) | Package changelogs and man pages | Not needed for automated CI/CD and container runtimes. | **~55 MB** |
| **Temporary Files & Caches** (`/var/cache/apt/*`, `/var/lib/apt/lists/*`, `/tmp/*`) | Installer bootstrap logs and apt index caches | Automatically refreshed on demand via `apt-get update`. | **~20 MB** |
| **Total Savings** | | | **~885+ MB (>50% reduction)** |

---

## 🚀 Available Presets & Image Tags

| Preset | Description | Tag Examples |
|---|---|---|
| **`minimal`** *(default)* | Clean base headless ALT Server with `apt-get`, `rpm`, and `systemd` | `runalsh/altlinux-patch:11.0-minimal`, `11.0`, `11`, `p11`, `latest` |
| **`samba`** | Samba AD Client infrastructure tools | `runalsh/altlinux-patch:11.0-samba` |
| **`virt`** | KVM / QEMU virtualization management | `runalsh/altlinux-patch:11.0-virt` |
| **`web`** | Web-based management interface | `runalsh/altlinux-patch:11.0-web` |

---

## 🔧 Environment Variables

| Variable | Default | Description |
|---|---|---|
| `PRESET_CHOICE` | `minimal` | Installation preset (`minimal`, `samba`, `virt`, `web`, `graph`). |
| `PUSH_TO_DOCKERHUB` | `false` | When `true`, pushes tagged images to Docker Hub. |
| `PUSH_TO_GHCR` | `false` | When `true`, pushes tagged images to GHCR. |
| `CLEANUP_DOCKER_IMAGES` | `true` | Automatically prunes local Docker images after push to prevent disk exhaustion. |
| `SKIP_EXISTS_CHECK` | `false` | Forces rebuilding and re-pushing even if remote tag exists. |
