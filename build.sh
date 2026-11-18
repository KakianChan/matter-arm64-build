#!/usr/bin/env bash

set -euo pipefail

SDK_COMMIT="e91ea83caae4adb1871aa4bbe93c4be2dd9e1abf"
WORKSPACE="$(cd "$(dirname "$0")" && pwd)"
SDK_ROOT="$WORKSPACE/connectedhomeip"
OUT_DIR="$SDK_ROOT/out/python-controller"

sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    autoconf \
    automake \
    bison \
    bluez \
    bridge-utils \
    clang \
    clang-format \
    cmake \
    curl \
    flex \
    g++ \
    gcc \
    git \
    git-lfs \
    gperf \
    iproute2 \
    jq \
    libavahi-client-dev \
    libavahi-common-dev \
    libcairo2-dev \
    libcurl4-openssl-dev \
    libdbus-1-dev \
    libdbus-glib-1-dev \
    libevent-dev \
    libgif-dev \
    libgirepository1.0-dev \
    libglib2.0-dev \
    libical-dev \
    libjpeg-dev \
    libmbedtls-dev \
    libncurses-dev \
    libnspr4-dev \
    libpango1.0-dev \
    libpcsclite-dev \
    libreadline-dev \
    libssl-dev \
    libtool \
    libudev-dev \
    libusb-1.0-0-dev \
    libxml2-dev \
    make \
    ninja-build \
    pkg-config \
    python3 \
    python3-dev \
    python3-pip \
    python3-venv \
    rsync \
    unzip \
    wget \
    zlib1g-dev

git lfs install

if [[ ! -d "$SDK_ROOT/.git" ]]; then
    git clone \
        --filter=blob:none \
        https://github.com/project-chip/connectedhomeip.git \
        "$SDK_ROOT"
fi

git -C "$SDK_ROOT" checkout --force "$SDK_COMMIT"
git -C "$SDK_ROOT" clean -ffdx \
    -e .environment \
    -e out/python-controller

"$SDK_ROOT/scripts/checkout_submodules.py" \
    --allow-changing-global-git-config \
    --shallow \
    --platform linux

git -C "$SDK_ROOT" apply --check "$WORKSPACE/stale-cache.patch"
git -C "$SDK_ROOT" apply "$WORKSPACE/stale-cache.patch"

cd "$SDK_ROOT"
bash scripts/bootstrap.sh
source scripts/activate.sh

gn_args=(
    'matter_log_json_payload_hex=true'
    'matter_log_json_payload_decode_full=true'
    'matter_enable_tracing_support=true'
    'chip_detail_logging=true'
    'chip_project_config_include_dirs=["//config/python"]'
    'chip_config_network_layer_ble=true'
    'chip_enable_ble=true'
    'chip_enable_nfc_based_commissioning=true'
    'chip_inet_config_enable_ipv4=true'
    'chip_crypto="openssl"'
    'chip_build_controller_dynamic_server=true'
    'chip_support_webrtc_python_bindings=true'
    'chip_device_config_enable_joint_fabric=true'
    'chip_mdns="platform"'
)

gn --root="$SDK_ROOT" gen "$OUT_DIR" --args="${gn_args[*]}"

ninja -j4 \
    -C "$OUT_DIR" \
    obj/src/controller/python/matter/_ChipDeviceCtrl.so

artifact_dir="$WORKSPACE/artifact"
mkdir -p "$artifact_dir"
cp "$OUT_DIR/obj/src/controller/python/matter/_ChipDeviceCtrl.so" "$artifact_dir/"

strings "$artifact_dir/_ChipDeviceCtrl.so" | grep -F \
    "Cached address rejected for" >/dev/null
strings "$artifact_dir/_ChipDeviceCtrl.so" | grep -F \
    "was unusable" >/dev/null

(
    cd "$artifact_dir"
    sha256sum _ChipDeviceCtrl.so > SHA256SUMS
)
