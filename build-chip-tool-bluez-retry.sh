#!/usr/bin/env bash

set -euo pipefail

SDK_COMMIT="e91ea83caae4adb1871aa4bbe93c4be2dd9e1abf"
WORKSPACE="$(cd "$(dirname "$0")" && pwd)"
SDK_ROOT="$WORKSPACE/connectedhomeip"
OUT_DIR="$SDK_ROOT/out/linux-arm64-chip-tool-bluez-retry"
ARTIFACT_DIR="$WORKSPACE/artifact"

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
    python-is-python3 \
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
    -e out

"$SDK_ROOT/scripts/checkout_submodules.py" \
    --allow-changing-global-git-config \
    --shallow \
    --platform linux

git -C "$SDK_ROOT" apply --check "$WORKSPACE/chip-tool-bluez-retry.patch"
git -C "$SDK_ROOT" apply "$WORKSPACE/chip-tool-bluez-retry.patch"

cd "$SDK_ROOT"
bash scripts/bootstrap.sh

export PW_ENVIRONMENT_ROOT="$SDK_ROOT/.environment"
set +u
source scripts/activate.sh
set -u

gn_args=(
    'target_cpu="arm64"'
    'is_clang=false'
    'is_debug=false'
    'chip_inet_config_enable_ipv4=false'
    'chip_config_network_layer_ble=true'
    'chip_enable_ble=true'
    'chip_enable_nfc_based_commissioning=true'
    'chip_mdns="platform"'
)

gn \
    --root="$SDK_ROOT" \
    gen "$OUT_DIR" \
    --check \
    --fail-on-unused-args \
    --args="${gn_args[*]}"

ninja -C "$OUT_DIR" -j4 chip-tool

mkdir -p "$ARTIFACT_DIR"
cp "$OUT_DIR/chip-tool" "$ARTIFACT_DIR/"
ldd "$ARTIFACT_DIR/chip-tool" > "$ARTIFACT_DIR/ldd.txt"

strings "$ARTIFACT_DIR/chip-tool" | grep -F \
    "ConnectDevice retry" >/dev/null

(
    cd "$ARTIFACT_DIR"
    sha256sum chip-tool > SHA256SUMS
)
