#!/usr/bin/env bash
#
# Regulatory Voice Archive (RVA) prerequisite installer
#
# Installs the OS packages required by RVA shell tools.
# This script does NOT install VoIPmonitor, MariaDB, Apache, or Cloud Commander.
# Those components are handled separately by install/install.sh.
#
# Usage:
#   sudo ./install/install-prerequisites.sh
#   sudo ./install/install-prerequisites.sh --check
#

set -Eeuo pipefail
IFS=$'\n\t'
umask 027

CHECK_ONLY=0

ok()   { printf '[ OK ] %s\n' "$*"; }
info() { printf '[INFO] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
die()  { printf '[ERROR] %s\n' "$*" >&2; exit 2; }

usage() {
    cat <<'EOF'
RVA prerequisite installer

Usage:
  sudo ./install/install-prerequisites.sh
  sudo ./install/install-prerequisites.sh --check

Options:
  --check      Validate prerequisites only; do not install packages.
  -h, --help   Show this help.

Packages installed on Ubuntu/Debian:
  tshark
  ffmpeg        (includes ffprobe and G.729 decoder on supported distro builds)
  tcpdump
  acl           (provides setfacl/getfacl)
  util-linux    (provides flock)
  xxd
  gawk          (provides awk)
  coreutils     (provides tr and common shell utilities)
  ethtool
  rrdtool
  zstd
  unzip
  curl

VoIPmonitor is intentionally NOT installed by this script.
EOF
}

require_root() {
    [[ $EUID -eq 0 ]] || die "Run this script as root (sudo)."
}

have_cmd() {
    command -v "$1" >/dev/null 2>&1
}

check_cmd() {
    local cmd="$1"
    local description="${2:-$1}"

    if have_cmd "$cmd"; then
        ok "$description"
        return 0
    fi

    warn "$description missing"
    return 1
}

validate_all() {
    local failures=0

    printf '\n============================================================\n'
    printf ' RVA PREREQUISITE VALIDATION\n'
    printf '============================================================\n'

    check_cmd tshark "tshark available" || failures=$((failures + 1))
    check_cmd ffmpeg "ffmpeg available" || failures=$((failures + 1))
    check_cmd ffprobe "ffprobe available" || failures=$((failures + 1))
    check_cmd tcpdump "tcpdump available" || failures=$((failures + 1))
    check_cmd setfacl "setfacl available" || failures=$((failures + 1))
    check_cmd getfacl "getfacl available" || failures=$((failures + 1))
    check_cmd flock "flock available" || failures=$((failures + 1))
    check_cmd xxd "xxd available" || failures=$((failures + 1))
    check_cmd awk "awk available" || failures=$((failures + 1))
    check_cmd tr "tr available" || failures=$((failures + 1))
    check_cmd ethtool "ethtool available" || failures=$((failures + 1))
    check_cmd rrdtool "rrdtool available" || failures=$((failures + 1))
    check_cmd zstd "zstd available" || failures=$((failures + 1))
    check_cmd unzip "unzip available" || failures=$((failures + 1))
    check_cmd curl "curl available" || failures=$((failures + 1))

    if have_cmd ffmpeg && ffmpeg -decoders 2>/dev/null | grep -qiE '(^|[[:space:]])g729([[:space:]]|$)'; then
        ok "FFmpeg G.729 decoder available"
    else
        warn "FFmpeg G.729 decoder NOT detected"
        failures=$((failures + 1))
    fi

    if have_cmd tshark; then
        local tshark_version
        tshark_version="$(tshark --version 2>/dev/null | head -1 || true)"
        [[ -n "$tshark_version" ]] && info "$tshark_version"
    fi

    if have_cmd ffmpeg; then
        local ffmpeg_version
        ffmpeg_version="$(ffmpeg -version 2>/dev/null | head -1 || true)"
        [[ -n "$ffmpeg_version" ]] && info "$ffmpeg_version"
    fi

    printf '\n'
    if (( failures == 0 )); then
        ok "All RVA OS prerequisites are ready"
        return 0
    fi

    warn "$failures prerequisite check(s) failed"
    return 2
}

install_packages() {
    have_cmd apt-get || die "This installer currently supports apt-based Ubuntu/Debian systems only."

    if [[ -r /etc/os-release ]]; then
        # shellcheck disable=SC1091
        source /etc/os-release
        info "Detected OS: ${PRETTY_NAME:-unknown}"
    fi

    # Prevent the Wireshark package from prompting interactively about packet
    # capture permissions. RVA tools are intended to run through sudo/root.
    if have_cmd debconf-set-selections; then
        printf '%s\n' 'wireshark-common wireshark-common/install-setuid boolean false' \
            | debconf-set-selections
    fi

    local packages=(
        tshark
        ffmpeg
        tcpdump
        acl
        util-linux
        xxd
        gawk
        coreutils
        ethtool
        rrdtool
        zstd
        unzip
        curl
    )

    printf '\n============================================================\n'
    printf ' INSTALL RVA OS PREREQUISITES\n'
    printf '============================================================\n'

    info "Refreshing apt metadata"
    DEBIAN_FRONTEND=noninteractive apt-get update

    info "Installing packages: ${packages[*]}"
    DEBIAN_FRONTEND=noninteractive apt-get install -y "${packages[@]}"

    ok "Package installation completed"
}

for arg in "$@"; do
    case "$arg" in
        --check) CHECK_ONLY=1 ;;
        -h|--help) usage; exit 0 ;;
        *) die "Unknown option: $arg" ;;
    esac
done

require_root

if (( CHECK_ONLY )); then
    validate_all
    exit $?
fi

install_packages

printf '\n'
info "Validating installed tools and codecs"
validate_all

printf '\nNext step:\n'
printf '  sudo ./install/install.sh --check\n'
printf 'or:\n'
printf '  sudo ./install/install.sh --with-all\n'
