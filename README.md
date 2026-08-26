# ALT Linux Server ISO to Docker Patch Images

Automated build of clean, lightweight Docker images for exact ALT Linux Server releases (**11.1**, **11.0**, **10.4**, **10.2**, **10.1**, **10.0**) built directly from official distribution ISOs into **`runalsh/altlinux-patch`** and **`ghcr.io/runalsh/altlinux-patch`**.

---

## ❓ Problem & Solution

Official ALT Linux Server installation media is distributed primarily as large installation ISO images (4.8+ GB).

Official Docker Hub registry (`alt/alt`, `alt/server`) publishes only major branch tags or rolling releases. Exact point release tags like `10.4`, `10.2`, `10.1`, `10.0`, `11.0`, or `11.1` locked to specific ISO baselines are not maintained.

The `altlinux-iso-docker-patch` pipeline automates:
1. Downloading official ALT Linux Server ISOs directly from high-speed BaseALT mirrors (`mirror.yandex.ru/altlinux`).
2. Mounting the installation ISO and dynamically extracting the clean root filesystem from live SquashFS images (`/live` on ALT 11.x, `/rescue` on ALT 10.x).
3. Performing deep optimization to strip non-container hardware drivers, kernel modules, firmware, and GUI installer components.
4. Importing the clean container rootfs into Docker and automatically publishing tagged images to **Docker Hub** and **GitHub Packages (GHCR)**.

---

## 📦 Available Images and Tags

### ALT Linux Server 11 (Branch `p11`)

| Tag | Aliases | OS Version | Docker Hub Image Link | GHCR Package Link |
|---|---|---|---|---|
| `11.1`, `11.1-minimal` | `11`, `11-minimal`, `p11`, `p11-minimal`, `latest`, `latest-minimal` | ALT Server 11.1 (Mendelevium) | [`runalsh/altlinux-patch:11.1`](https://hub.docker.com/r/runalsh/altlinux-patch/tags) | [`ghcr.io/runalsh/altlinux-patch:11.1`](https://github.com/users/runalsh/packages/container/package/altlinux-patch) |
| `11.0`, `11.0-minimal` | - | ALT Server 11.0 (Mendelevium) | [`runalsh/altlinux-patch:11.0`](https://hub.docker.com/r/runalsh/altlinux-patch/tags) | [`ghcr.io/runalsh/altlinux-patch:11.0`](https://github.com/users/runalsh/packages/container/package/altlinux-patch) |

### ALT Linux Server 10 (Branch `p10`)

| Tag | Aliases | OS Version | Docker Hub Image Link | GHCR Package Link |
|---|---|---|---|---|
| `10.4`, `10.4-minimal` | `10`, `10-minimal`, `p10`, `p10-minimal` | ALT Server 10.4 (Mendelevium) | [`runalsh/altlinux-patch:10.4`](https://hub.docker.com/r/runalsh/altlinux-patch/tags) | [`ghcr.io/runalsh/altlinux-patch:10.4`](https://github.com/users/runalsh/packages/container/package/altlinux-patch) |
| `10.2`, `10.2-minimal` | - | ALT Server 10.2 (Mendelevium) | [`runalsh/altlinux-patch:10.2`](https://hub.docker.com/r/runalsh/altlinux-patch/tags) | [`ghcr.io/runalsh/altlinux-patch:10.2`](https://github.com/users/runalsh/packages/container/package/altlinux-patch) |
| `10.1`, `10.1-minimal` | - | ALT Server 10.1 (Mendelevium) | [`runalsh/altlinux-patch:10.1`](https://hub.docker.com/r/runalsh/altlinux-patch/tags) | [`ghcr.io/runalsh/altlinux-patch:10.1`](https://github.com/users/runalsh/packages/container/package/altlinux-patch) |
| `10.0`, `10.0-minimal` | - | ALT Server 10.0 (Mendelevium) | [`runalsh/altlinux-patch:10.0`](https://hub.docker.com/r/runalsh/altlinux-patch/tags) | [`ghcr.io/runalsh/altlinux-patch:10.0`](https://github.com/users/runalsh/packages/container/package/altlinux-patch) |

---

## 🛠 Quick Start

### Docker Hub

```bash
# ALT Server 11.1
docker run --rm -it runalsh/altlinux-patch:11.1 cat /etc/altlinux-release

# ALT Server 10.4
docker run --rm -it runalsh/altlinux-patch:10.4 cat /etc/altlinux-release

# ALT Server 10.1
docker run --rm -it runalsh/altlinux-patch:10.1 cat /etc/altlinux-release
```

### GitHub Container Registry (GHCR)

```bash
# ALT Server 11.1
docker run --rm -it ghcr.io/runalsh/altlinux-patch:11.1 cat /etc/altlinux-release

# ALT Server 10.4
docker run --rm -it ghcr.io/runalsh/altlinux-patch:10.4 cat /etc/altlinux-release
```

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
| **`minimal`** *(default)* | Clean base headless ALT Server with `apt-get`, `rpm`, and `systemd` | `runalsh/altlinux-patch:11.1-minimal`, `11.1`, `11`, `p11`, `latest` |
| **`samba`** | Samba AD Client infrastructure tools | `runalsh/altlinux-patch:11.1-samba` |
| **`virt`** | KVM / QEMU virtualization management | `runalsh/altlinux-patch:11.1-virt` |
| **`web`** | Web-based management interface | `runalsh/altlinux-patch:11.1-web` |

---

## 🔧 Environment Variables

The `build.sh` script supports the following configuration environment variables:

| Variable | Default | Description |
|---|---|---|
| `PRESET_CHOICE` | `minimal` | Installation preset (`minimal`, `samba`, `virt`, `web`). |
| `PUSH_TO_DOCKERHUB` | `false` | When `true`, pushes tagged images to Docker Hub (`runalsh/altlinux-patch:<tag>`). |
| `PUSH_TO_GHCR` | `false` | When `true`, pushes tagged images to GitHub Packages / GHCR (`ghcr.io/runalsh/altlinux-patch:<tag>`). |
| `CLEANUP_DOCKER_IMAGES` | `true` | Automatically prunes local Docker images after push to prevent disk exhaustion. |
| `SKIP_EXISTS_CHECK` | `false` | When `false`, skips already published tags. Set to `true` to force rebuilding. |

---

## ⚙️ Repository Structure

```text
.
├── .github/workflows/
│   └── build-and-push.yml  # Automated CI pipeline for building, verifying, and pushing to Docker Hub & GHCR
├── build.sh                 # Extraction and optimization engine (mounts ISO, unpacks SquashFS, optimizes rootfs)
├── releases.txt             # Manifest of ALT Server releases and mirror download URLs
└── README.md                # Project documentation
```

---

## 🔐 GitHub Actions Secrets

The CI workflow requires the following secrets in GitHub Secrets:
- `DOCKERHUB_USERNAME`: Docker Hub username (`runalsh`)
- `DOCKERHUB_TOKEN`: Docker Hub Personal Access Token
- `${{ secrets.GITHUB_TOKEN }}`: Automatically provided by GitHub for GHCR publishing
