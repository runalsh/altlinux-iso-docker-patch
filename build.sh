#!/bin/bash
set -euo pipefail

s() {
  if [ "$(id -u)" -ne 0 ]; then
    if command -v sudo &>/dev/null; then
      sudo "$@"
    else
      echo "Error: sudo not found and not running as root!" >&2
      exit 1
    fi
  else
    "$@"
  fi
}

log_info()    { echo -e "\033[1;34m[INFO]\033[0m $*"; }
log_success() { echo -e "\033[1;32m[SUCCESS]\033[0m $*"; }
log_warn()    { echo -e "\033[1;33m[WARN]\033[0m $*"; }
log_error()   { echo -e "\033[1;31m[ERROR]\033[0m $*"; }
log_exec()    { echo -e "\033[1;36m[EXEC]\033[0m $*"; }

IMAGE_NAME="runalsh/altlinux-patch"
GHCR_IMAGE_NAME="ghcr.io/runalsh/altlinux-patch"
RELEASES_FILE="releases.txt"

# Pre-cleanup temporary files and leftover images from previous runs
s umount -f /tmp/altlinux-iso-patch_* 2>/dev/null || true
s rm -rf /tmp/altlinux-iso-patch_* 2>/dev/null || true
if [ "${CLEANUP_DOCKER_IMAGES:-true}" = "true" ]; then
    docker images --format '{{.Repository}}:{{.Tag}}' | grep -E '^((ghcr\.io/)?runalsh/altlinux-patch)(:|$)' | xargs -r docker rmi -f 2>/dev/null || true
fi

install_deps() {
  log_info "Ensuring required host utilities are installed..."
  local pkgs=()
  command -v curl &>/dev/null || pkgs+=(curl)
  command -v tar &>/dev/null || pkgs+=(tar)
  command -v squashfs-tools &>/dev/null || pkgs+=(squashfs-tools)
  command -v 7z &>/dev/null || pkgs+=(p7zip-full)
  
  if [ ${#pkgs[@]} -gt 0 ]; then
    if command -v apt-get &>/dev/null; then
      s apt-get update -qq || true
      s apt-get install -y -qq "${pkgs[@]}" || true
    elif command -v dnf &>/dev/null; then
      s dnf install -y -q "${pkgs[@]}" || true
    elif command -v yum &>/dev/null; then
      s yum install -y -q "${pkgs[@]}" || true
    fi
  fi
}

install_deps

PRESET_CHOICE="minimal"
CLI_TARGET_TAG=""
SKIP_EXISTS_CHECK="${SKIP_EXISTS_CHECK:-false}"
PUSH_TO_DOCKERHUB="${PUSH_TO_DOCKERHUB:-false}"
PUSH_TO_GHCR="${PUSH_TO_GHCR:-false}"
CLEANUP_DOCKER_IMAGES="${CLEANUP_DOCKER_IMAGES:-true}"
TEST_VERSION="${TEST_VERSION:-true}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --preset)
      PRESET_CHOICE="$2"
      shift 2
      ;;
    --preset=*)
      PRESET_CHOICE="${1#*=}"
      shift 1
      ;;
    --skip-exists-check|--force-rebuild)
      SKIP_EXISTS_CHECK="true"
      shift 1
      ;;
    --push-dockerhub)
      PUSH_TO_DOCKERHUB="true"
      shift 1
      ;;
    --push-ghcr)
      PUSH_TO_GHCR="true"
      shift 1
      ;;
    --no-cleanup)
      CLEANUP_DOCKER_IMAGES="false"
      shift 1
      ;;
    -*)
      log_warn "Unknown flag: $1"
      shift 1
      ;;
    *)
      if [ -z "$CLI_TARGET_TAG" ]; then
        CLI_TARGET_TAG="$1"
      fi
      shift 1
      ;;
  esac
done

if [ ! -f "$RELEASES_FILE" ]; then
  log_error "File $RELEASES_FILE not found!"
  exit 1
fi

OVERALL_LATEST=$(grep -v '^#' "$RELEASES_FILE" | grep -v '^$' | sort -V | tail -n 1 | awk '{print $1}')
log_info "Target Repository: ${IMAGE_NAME} / ${GHCR_IMAGE_NAME}"
log_info "Preset choice: ${PRESET_CHOICE}"
log_info "Overall latest release tag in file: ${OVERALL_LATEST}"

while read -r tag source || [ -n "$tag" ]; do
  [[ -z "$tag" || "$tag" =~ ^# ]] && continue

  if [ -n "$CLI_TARGET_TAG" ] && [ "$CLI_TARGET_TAG" != "all" ] && [ "$CLI_TARGET_TAG" != "$tag" ]; then
    continue
  fi

  echo "=========================================================="
  log_info "Processing ALT Linux release tag: ${tag} (Preset: ${PRESET_CHOICE})"
  log_info "Source: ${source}"
  echo "=========================================================="

  FULL_IMAGE_TAG="${IMAGE_NAME}:${tag}-${PRESET_CHOICE}"
  FULL_GHCR_TAG="${GHCR_IMAGE_NAME}:${tag}-${PRESET_CHOICE}"
  CREATED_TAGS=("${FULL_IMAGE_TAG}")

  MAJOR_VER="${tag%%.*}"
  LATEST_IN_TRACK=$(grep -v '^#' "$RELEASES_FILE" | grep -E "^${MAJOR_VER}\." | sort -V | tail -n 1 | awk '{print $1}')
  
  ALL_EXTRA_TAGS=()
  if [ "$PRESET_CHOICE" = "minimal" ]; then
    ALL_EXTRA_TAGS+=("${tag}")
    if [ "$tag" = "$LATEST_IN_TRACK" ]; then
      ALL_EXTRA_TAGS+=("${MAJOR_VER}" "${MAJOR_VER}-${PRESET_CHOICE}")
      ALL_EXTRA_TAGS+=("p${MAJOR_VER}" "p${MAJOR_VER}-${PRESET_CHOICE}")
    fi
    if [ "$tag" = "$OVERALL_LATEST" ]; then
      ALL_EXTRA_TAGS+=("latest" "latest-${PRESET_CHOICE}")
    fi
  else
    if [ "$tag" = "$LATEST_IN_TRACK" ]; then
      ALL_EXTRA_TAGS+=("${MAJOR_VER}-${PRESET_CHOICE}" "p${MAJOR_VER}-${PRESET_CHOICE}")
    fi
    if [ "$tag" = "$OVERALL_LATEST" ]; then
      ALL_EXTRA_TAGS+=("latest-${PRESET_CHOICE}")
    fi
  fi

  # Remote existence check
  if [ "$SKIP_EXISTS_CHECK" != "true" ]; then
    dh_exists=false
    ghcr_exists=false
    if [ "$PUSH_TO_DOCKERHUB" = "true" ]; then
      if docker manifest inspect "${FULL_IMAGE_TAG}" &>/dev/null || curl -sfSL "https://hub.docker.com/v2/repositories/${IMAGE_NAME}/tags/${tag}-${PRESET_CHOICE}/" &>/dev/null; then
        dh_exists=true
      fi
    else
      dh_exists=true
    fi
    if [ "$PUSH_TO_GHCR" = "true" ]; then
      if docker manifest inspect "${FULL_GHCR_TAG}" &>/dev/null; then
        ghcr_exists=true
      fi
    else
      ghcr_exists=true
    fi
    if [ "$dh_exists" = "true" ] && [ "$ghcr_exists" = "true" ] && { [ "$PUSH_TO_DOCKERHUB" = "true" ] || [ "$PUSH_TO_GHCR" = "true" ]; }; then
      log_success "Tag ${FULL_IMAGE_TAG} already exists on all enabled registries. Skipping build."
      continue
    fi
  fi

  RAND_ID=$(head /dev/urandom | tr -dc a-z0-9 | head -c 8 ; echo '')
  LOCAL_ISO=""
  MNT_ISO="/tmp/altlinux-iso-patch_iso_mnt_${RAND_ID}"
  MNT_SQUASH="/tmp/altlinux-iso-patch_squash_mnt_${RAND_ID}"

  cleanup_iteration() {
    s umount -f "$MNT_SQUASH" 2>/dev/null || true
    s umount -f "$MNT_ISO" 2>/dev/null || true
    s rm -rf "$MNT_SQUASH" "$MNT_ISO"
    if [[ "$source" =~ ^https?:// ]] && [ -f "${LOCAL_ISO:-}" ]; then
      rm -f "$LOCAL_ISO"
    fi
    if [ "${CLEANUP_DOCKER_IMAGES:-true}" = "true" ] && [ ${#CREATED_TAGS[@]} -gt 0 ]; then
      for img_tag in "${CREATED_TAGS[@]}"; do
        docker rmi -f "${img_tag}" 2>/dev/null || true
      done
    fi
  }
  trap cleanup_iteration EXIT INT TERM HUP

  s mkdir -p "$MNT_ISO" "$MNT_SQUASH"

  if [[ "$source" =~ ^https?:// ]]; then
    fname=$(basename "$source")
    if [ -f "/$fname" ]; then
      LOCAL_ISO="/$fname"
      log_info "Found local cached ISO: $LOCAL_ISO (download skipped)"
    elif [ -f "./$fname" ]; then
      LOCAL_ISO="./$fname"
      log_info "Found local cached ISO: $LOCAL_ISO (download skipped)"
    else
      LOCAL_ISO="/tmp/altlinux-iso-patch_download_${RAND_ID}.iso"
      log_info "Downloading ISO from ${source}..."
      log_exec "curl -fLC - -sS --show-error -o $LOCAL_ISO $source"
      curl -fLC - -sS --show-error -o "$LOCAL_ISO" "$source"
      ISO_SIZE=$(du -h "$LOCAL_ISO" | awk '{print $1}')
      log_success "Download complete. File size: ${ISO_SIZE}"
    fi
  else
    LOCAL_ISO="$source"
  fi

  log_info "1. Mounting ISO..."
  s mount -o loop,ro "$LOCAL_ISO" "$MNT_ISO"

  log_info "2. Mounting live SquashFS image..."
  s mount -o loop,ro "${MNT_ISO}/live" "$MNT_SQUASH"

  log_info "3. Exporting optimized rootfs (excluding kernel, firmware, llvm/mesa, alterator, docs, foreign locales) into Docker..."
  s tar -C "$MNT_SQUASH" \
      --exclude="./usr/lib/firmware" \
      --exclude="./lib/firmware" \
      --exclude="./usr/lib/modules" \
      --exclude="./lib/modules" \
      --exclude="./boot/vmlinuz*" \
      --exclude="./boot/initrd*" \
      --exclude="./boot/System.map*" \
      --exclude="./boot/config*" \
      --exclude="./usr/lib/llvm*" \
      --exclude="./usr/lib64/gallium-pipe" \
      --exclude="./usr/lib64/dri" \
      --exclude="./usr/share/qt6" \
      --exclude="./usr/share/alterator*" \
      --exclude="./usr/share/doc/*" \
      --exclude="./usr/share/man/*" \
      --exclude="./usr/share/info/*" \
      --exclude="./var/cache/apt/*" \
      --exclude="./var/lib/apt/lists/*" \
      --exclude="./var/log/*" \
      --exclude="./tmp/*" \
      --exclude="./var/tmp/*" \
      -c . | docker import \
        -c 'ENV container=docker' \
        -c 'ENV LANG=ru_RU.UTF-8' \
        -c 'CMD ["/bin/bash"]' \
        - "${FULL_IMAGE_TAG}"

  log_info "3.1. Eagerly unmounting and cleaning up ISO and SquashFS mounts..."
  s umount -f "$MNT_SQUASH" 2>/dev/null || true
  s umount -f "$MNT_ISO" 2>/dev/null || true
  s rm -rf "$MNT_SQUASH" "$MNT_ISO"
  if [[ "$source" =~ ^https?:// ]] && [ -f "${LOCAL_ISO:-}" ]; then
    log_info "Removing downloaded ISO: $LOCAL_ISO to save disk space..."
    rm -f "$LOCAL_ISO"
  fi

  if [ "$TEST_VERSION" = "true" ]; then
    log_info "4. Testing container functionality and version info..."
    docker run --rm "${FULL_IMAGE_TAG}" bash -c "
      echo '=== /etc/altlinux-release ==='
      cat /etc/altlinux-release 2>/dev/null || true
      echo '=== /etc/os-release ==='
      cat /etc/os-release 2>/dev/null || true
      echo '=== Package manager test ==='
      apt-get --version 2>/dev/null | head -n 1 || rpm --version
    "
  fi

  # Tag extra aliases
  for extra_tag in "${ALL_EXTRA_TAGS[@]}"; do
    EXT_IMAGE_TAG="${IMAGE_NAME}:${extra_tag}"
    EXT_GHCR_TAG="${GHCR_IMAGE_NAME}:${extra_tag}"
    docker tag "${FULL_IMAGE_TAG}" "${EXT_IMAGE_TAG}"
    docker tag "${FULL_IMAGE_TAG}" "${EXT_GHCR_TAG}"
    CREATED_TAGS+=("${EXT_IMAGE_TAG}" "${EXT_GHCR_TAG}")
  done
  docker tag "${FULL_IMAGE_TAG}" "${FULL_GHCR_TAG}"
  CREATED_TAGS+=("${FULL_GHCR_TAG}")

  if [ "$PUSH_TO_DOCKERHUB" = "true" ]; then
    log_info "5. Pushing images to Docker Hub..."
    docker push "${FULL_IMAGE_TAG}" || true
    for extra_tag in "${ALL_EXTRA_TAGS[@]}"; do
      docker push "${IMAGE_NAME}:${extra_tag}" || true
    done
  fi

  if [ "$PUSH_TO_GHCR" = "true" ]; then
    log_info "6. Pushing images to GitHub Container Registry (GHCR)..."
    docker push "${FULL_GHCR_TAG}" || true
    for extra_tag in "${ALL_EXTRA_TAGS[@]}"; do
      docker push "${GHCR_IMAGE_NAME}:${extra_tag}" || true
    done
  fi

  log_info "7. Cleaning up iteration artifacts and local Docker tags..."
  cleanup_iteration
  CREATED_TAGS=()

  log_success "Successfully completed tag ${tag}-${PRESET_CHOICE}!"
  echo
done < "$RELEASES_FILE"

if [ "${CLEANUP_DOCKER_IMAGES:-true}" = "true" ]; then
  log_info "Performing final regex-based Docker cleanup of all altlinux-patch images..."
  docker images --format '{{.Repository}}:{{.Tag}}' | grep -E '^((ghcr\.io/)?runalsh/altlinux-patch)(:|$)' | xargs -r docker rmi -f 2>/dev/null || true
fi

log_success "All ALT Linux images processed successfully!"
