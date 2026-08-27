#!/usr/bin/env bash
#
# Regulatory Voice Archive (RVA) installer
#
# Usage:
#   sudo ./install/install.sh
#   sudo ./install/install.sh --check
#   sudo ./install/install.sh --with-mariadb
#   sudo ./install/install.sh --with-cloudcmd
#   sudo ./install/install.sh --with-apache
#   sudo ./install/install.sh --with-all
#
# The default mode installs only RVA files and does not install optional
# infrastructure components. Optional flags explicitly opt in to those changes.

set -Eeuo pipefail
IFS=$'\n\t'
umask 027

readonly PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly RVA_ETC="/etc/rva"
readonly RVA_BIN="/usr/local/sbin"
readonly RVA_CONF="${RVA_ETC}/rva.conf"
readonly DB_CNF="${RVA_ETC}/database.cnf"
readonly CLOUDCMD_HOME="/var/lib/cloudcmd"
readonly CLOUDCMD_CONF="${CLOUDCMD_HOME}/.cloudcmd.json"
readonly CLOUDCMD_SERVICE="/etc/systemd/system/cloudcmd.service"
readonly APACHE_CONF="/etc/apache2/conf-available/rva-cloudcmd.conf"

WITH_MARIADB=0
WITH_CLOUDCMD=0
WITH_APACHE=0
CHECK_ONLY=0

OK_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

ok() {
    printf '[ OK ] %s\n' "$*"
    OK_COUNT=$((OK_COUNT + 1))
}

info() {
    printf '[INFO] %s\n' "$*"
}

warn() {
    printf '[WARN] %s\n' "$*" >&2
    WARN_COUNT=$((WARN_COUNT + 1))
}

fail() {
    printf '[FAIL] %s\n' "$*" >&2
    FAIL_COUNT=$((FAIL_COUNT + 1))
}

die() {
    printf '[ERROR] %s\n' "$*" >&2
    exit 2
}

section() {
    printf '\n============================================================\n'
    printf ' %s\n' "$1"
    printf '============================================================\n'
}

usage() {
    cat <<'EOF'
RVA installer

Usage:
  sudo ./install/install.sh [option ...]

Options:
  --check             Validate the server only. Do not modify anything.
  --with-mariadb      Install/enable MariaDB and prepare the RVA DB client.
  --with-cloudcmd     Install/configure Cloud Commander as an optional file browser.
  --with-apache       Install/configure Apache reverse proxy integration.
  --with-all          Enable MariaDB + Cloud Commander + Apache installation.
  -h, --help          Show this help.

Without optional flags, the installer only deploys RVA configuration templates
and commands. Existing configuration files are never overwritten automatically.

Environment variables for unattended setup:
  RVA_DB_USER               Database account to create (default: rva)
  RVA_DB_PASSWORD           Password for the RVA database account
  RVA_CLOUDCMD_USERNAME     Cloud Commander login (default: rvaadmin)
  RVA_CLOUDCMD_PASSWORD     Cloud Commander password
EOF
}

require_root() {
    [[ $EUID -eq 0 ]] || die "Run this installer as root (sudo)."
}

have_cmd() {
    command -v "$1" >/dev/null 2>&1
}

apt_install() {
    (( $# > 0 )) || return 0

    have_cmd apt-get || die "This installer currently supports apt-based Ubuntu/Debian systems."

    info "Installing packages: $*"
    DEBIAN_FRONTEND=noninteractive apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y "$@"
}

load_runtime_config() {
    SPOOL_ROOT="/var/spool/voipmonitor"
    VOIPMONITOR_BIN="/usr/local/sbin/voipmonitor"
    DB_NAME="voipmonitor"
    CLOUDCMD_USER="cloudcmd"

    if [[ -r "$RVA_CONF" ]]; then
        # rva.conf is root-managed and uses simple KEY=VALUE assignments.
        # shellcheck disable=SC1090
        source "$RVA_CONF"
    fi
}

check_command() {
    local cmd="$1"
    local required="${2:-required}"

    if have_cmd "$cmd"; then
        ok "$cmd available"
    elif [[ "$required" == "required" ]]; then
        fail "$cmd missing"
    else
        warn "$cmd missing (optional)"
    fi
}

check_environment() {
    section "RVA PREREQUISITE CHECK"

    for cmd in bash mariadb tshark ffmpeg ffprobe tcpdump setfacl flock xxd awk tr; do
        check_command "$cmd"
    done

    if have_cmd ffmpeg && ffmpeg -decoders 2>/dev/null | grep -qi g729; then
        ok "FFmpeg includes G.729 decoder"
    else
        fail "FFmpeg does not report a G.729 decoder"
    fi

    if [[ -x "${VOIPMONITOR_BIN}" ]] || have_cmd voipmonitor; then
        ok "VoIPmonitor detected"
    else
        fail "VoIPmonitor not detected (RVA requires an existing VoIPmonitor installation)"
    fi

    if [[ -d "${SPOOL_ROOT}" ]]; then
        ok "VoIPmonitor spool detected: ${SPOOL_ROOT}"
    else
        fail "VoIPmonitor spool not found: ${SPOOL_ROOT}"
    fi

    if systemctl list-unit-files mariadb.service >/dev/null 2>&1; then
        ok "MariaDB installed"
    else
        warn "MariaDB not installed"
    fi

    if systemctl list-unit-files apache2.service >/dev/null 2>&1; then
        ok "Apache installed"
    else
        warn "Apache not installed (optional for shell tools; required for web/proxy integration)"
    fi

    if have_cmd cloudcmd; then
        ok "Cloud Commander installed (optional)"
    else
        warn "Cloud Commander not installed (optional)"
    fi
}

install_base_rva() {
    section "INSTALL RVA CORE"

    install -d -m 0750 -o root -g root "$RVA_ETC"
    ok "Configuration directory ready: $RVA_ETC"

    if [[ ! -e "$RVA_CONF" ]]; then
        install -m 0640 -o root -g root \
            "${PROJECT_ROOT}/config/rva.conf.example" \
            "$RVA_CONF"
        ok "Installed $RVA_CONF"
    else
        info "$RVA_CONF already exists; leaving it unchanged"
    fi

    if [[ ! -e "$DB_CNF" ]]; then
        install -m 0600 -o root -g root \
            "${PROJECT_ROOT}/config/database.cnf.example" \
            "$DB_CNF"
        ok "Installed database client template: $DB_CNF"
        warn "Edit $DB_CNF or use --with-mariadb to configure a dedicated RVA account"
    else
        info "$DB_CNF already exists; leaving it unchanged"
    fi

    local script
    for script in rva-healthcheck rva-morning-check rva-genera-wav; do
        [[ -f "${PROJECT_ROOT}/scripts/${script}" ]] \
            || die "Missing repository file: scripts/${script}"

        bash -n "${PROJECT_ROOT}/scripts/${script}"
        install -m 0750 -o root -g root \
            "${PROJECT_ROOT}/scripts/${script}" \
            "${RVA_BIN}/${script}"
        ok "Installed command: ${script}"
    done
}

install_mariadb_component() {
    section "MARIADB COMPONENT"

    if ! have_cmd mariadb; then
        apt_install mariadb-server mariadb-client
    fi

    systemctl enable --now mariadb
    ok "MariaDB enabled and running"

    if ! mariadb -e 'SELECT 1;' >/dev/null 2>&1; then
        warn "Root socket administration is not available; skipping automatic database/user creation"
        warn "Configure $DB_CNF manually"
        return 0
    fi

    local db_name="${DB_NAME:-voipmonitor}"
    local db_user="${RVA_DB_USER:-rva}"
    local db_password="${RVA_DB_PASSWORD:-}"

    mariadb -e "CREATE DATABASE IF NOT EXISTS \`${db_name}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;"
    ok "Database present: ${db_name}"

    if [[ -z "$db_password" && -t 0 ]]; then
        printf 'Password for MariaDB user %s (leave blank to configure manually): ' "$db_user" >&2
        read -r -s db_password
        printf '\n' >&2
    fi

    if [[ -z "$db_password" ]]; then
        warn "No RVA_DB_PASSWORD supplied; database user was not created"
        warn "Configure $DB_CNF manually before running RVA database tools"
        return 0
    fi

    if [[ "$db_user" == *"'"* || "$db_password" == *"'"* ]]; then
        die "Database username/password may not contain a single quote when using this installer. Configure them manually instead."
    fi

    mariadb <<SQL
CREATE USER IF NOT EXISTS '${db_user}'@'localhost' IDENTIFIED BY '${db_password}';
ALTER USER '${db_user}'@'localhost' IDENTIFIED BY '${db_password}';
GRANT SELECT ON \`${db_name}\`.* TO '${db_user}'@'localhost';
FLUSH PRIVILEGES;
SQL

    cat >"$DB_CNF" <<EOF
[client]
host=localhost
port=3306
user=${db_user}
password=${db_password}
database=${db_name}
EOF
    chown root:root "$DB_CNF"
    chmod 0600 "$DB_CNF"

    ok "Dedicated read-only RVA database account configured: ${db_user}@localhost"

    if mariadb --defaults-extra-file="$DB_CNF" --batch --skip-column-names -e 'SELECT 1;' 2>/dev/null | grep -qx '1'; then
        ok "RVA database connection successful"
    else
        fail "RVA database connection test failed"
    fi

    local cdr_table
    cdr_table="$(mariadb --defaults-extra-file="$DB_CNF" --batch --skip-column-names -e \
        "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${db_name}' AND table_name='cdr';" 2>/dev/null || true)"

    if [[ "$cdr_table" == "1" ]]; then
        ok "VoIPmonitor schema detected (${db_name}.cdr)"
    else
        warn "${db_name}.cdr is not present yet; VoIPmonitor must initialize its schema before RVA can query calls"
    fi
}

install_cloudcmd_component() {
    section "CLOUD COMMANDER COMPONENT"

    if ! have_cmd cloudcmd; then
        if ! have_cmd npm; then
            apt_install nodejs npm
        fi
        npm install -g cloudcmd
    fi

    have_cmd cloudcmd || die "Cloud Commander installation failed"
    ok "Cloud Commander installed: $(cloudcmd --version 2>/dev/null | head -1 || true)"

    if ! id cloudcmd >/dev/null 2>&1; then
        useradd --system --home "$CLOUDCMD_HOME" --create-home --shell /usr/sbin/nologin cloudcmd
        ok "Created system user: cloudcmd"
    fi

    install -d -m 0750 -o cloudcmd -g cloudcmd "$CLOUDCMD_HOME"

    local cc_user="${RVA_CLOUDCMD_USERNAME:-rvaadmin}"
    local cc_password="${RVA_CLOUDCMD_PASSWORD:-}"

    if [[ -z "$cc_password" && -t 0 ]]; then
        printf 'Cloud Commander password for %s (leave blank to configure later): ' "$cc_user" >&2
        read -r -s cc_password
        printf '\n' >&2
    fi

    if [[ -z "$cc_password" ]]; then
        warn "No RVA_CLOUDCMD_PASSWORD supplied; Cloud Commander service configuration was skipped"
        warn "Configure Cloud Commander authentication before exposing it through Apache"
        return 0
    fi

    sudo -u cloudcmd HOME="$CLOUDCMD_HOME" cloudcmd \
        --auth \
        --username "$cc_user" \
        --password "$cc_password" \
        --root "$SPOOL_ROOT" \
        --prefix /cloudcmd \
        --port 8000 \
        --no-terminal \
        --no-console \
        --no-contact \
        --no-export \
        --no-import \
        --no-config-dialog \
        --no-config-auth \
        --no-config-port \
        --save \
        --no-server >/dev/null

    # Cloud Commander 19.x stores the password as a hash after --save.
    # Force loopback binding and the classic context menu without exposing
    # the clear-text password in the JSON configuration.
    node - "$CLOUDCMD_CONF" <<'NODE'
const fs = require('fs');
const file = process.argv[2];
const cfg = JSON.parse(fs.readFileSync(file, 'utf8'));
cfg.ip = '127.0.0.1';
cfg.menu = 'supermenu';
cfg.root = cfg.root || '/var/spool/voipmonitor';
cfg.prefix = '/cloudcmd';
cfg.port = 8000;
cfg.auth = true;
fs.writeFileSync(file, JSON.stringify(cfg, null, 4) + '\n');
NODE

    chown cloudcmd:cloudcmd "$CLOUDCMD_CONF"
    chmod 0600 "$CLOUDCMD_CONF"

    cat >"$CLOUDCMD_SERVICE" <<EOF
[Unit]
Description=Cloud Commander RVA File Browser
After=network.target
RequiresMountsFor=${SPOOL_ROOT}

[Service]
Type=simple
User=cloudcmd
Group=cloudcmd
Environment=HOME=${CLOUDCMD_HOME}
ExecStart=$(command -v cloudcmd) --no-open
Restart=on-failure
RestartSec=5
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadOnlyPaths=${SPOOL_ROOT}
ReadWritePaths=${CLOUDCMD_HOME}

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable --now cloudcmd
    ok "Cloud Commander service enabled"

    sleep 1
    local http_code
    http_code="$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8000/cloudcmd/ 2>/dev/null || true)"
    case "$http_code" in
        200|302|401) ok "Cloud Commander responds locally (HTTP ${http_code})" ;;
        *) warn "Cloud Commander local response is unexpected (HTTP ${http_code:-N/A})" ;;
    esac
}

install_apache_component() {
    section "APACHE COMPONENT"

    if ! have_cmd apache2ctl; then
        apt_install apache2
    fi

    systemctl enable --now apache2

    a2enmod proxy >/dev/null
    a2enmod proxy_http >/dev/null
    a2enmod proxy_wstunnel >/dev/null
    a2enmod rewrite >/dev/null
    a2enmod headers >/dev/null
    ok "Apache proxy modules enabled"

    if have_cmd cloudcmd && [[ -f "$CLOUDCMD_CONF" ]]; then
        install -m 0644 -o root -g root \
            "${PROJECT_ROOT}/config/apache/cloudcmd.conf.example" \
            "$APACHE_CONF"
        a2enconf rva-cloudcmd >/dev/null
        apache2ctl configtest
        systemctl reload apache2
        ok "Apache /cloudcmd/ reverse proxy enabled"
    else
        warn "Cloud Commander is not configured; Apache installed but /cloudcmd/ proxy was not enabled"
        warn "Run this installer again with --with-cloudcmd --with-apache after configuring Cloud Commander"
    fi
}

final_validation() {
    section "FINAL VALIDATION"

    load_runtime_config

    local script
    for script in rva-healthcheck rva-morning-check rva-genera-wav; do
        if [[ -x "${RVA_BIN}/${script}" ]]; then
            bash -n "${RVA_BIN}/${script}"
            ok "${script} syntax OK"
        else
            fail "${RVA_BIN}/${script} missing or not executable"
        fi
    done

    if [[ -r "$DB_CNF" ]] && ! grep -qE 'CHANGE_ME|YOUR_PASSWORD' "$DB_CNF" 2>/dev/null; then
        if mariadb --defaults-extra-file="$DB_CNF" --batch --skip-column-names -e 'SELECT 1;' >/dev/null 2>&1; then
            ok "Database client configuration works"
        else
            warn "Database client configuration exists but connection failed"
        fi
    else
        warn "Database credentials still require configuration: $DB_CNF"
    fi

    if [[ -d "$SPOOL_ROOT" ]]; then
        ok "Spool accessible: $SPOOL_ROOT"
    else
        fail "Spool unavailable: $SPOOL_ROOT"
    fi
}

summary() {
    section "INSTALLATION SUMMARY"
    printf ' OK:   %d\n' "$OK_COUNT"
    printf ' WARN: %d\n' "$WARN_COUNT"
    printf ' FAIL: %d\n' "$FAIL_COUNT"
    printf '\n'

    if (( FAIL_COUNT > 0 )); then
        printf 'RVA installation requires attention.\n'
        return 2
    fi

    printf 'RVA core installation completed.\n'
    printf '\nNext steps:\n'
    printf '  1. Review %s\n' "$RVA_CONF"
    printf '  2. Review %s\n' "$DB_CNF"
    printf '  3. Run: sudo rva-healthcheck\n'
    printf '  4. Run: sudo rva-morning-check\n'
    printf '  5. Generate audio with: sudo rva-genera-wav <CDR_ID>\n'
}

parse_args() {
    while (( $# > 0 )); do
        case "$1" in
            --check)
                CHECK_ONLY=1
                ;;
            --with-mariadb)
                WITH_MARIADB=1
                ;;
            --with-cloudcmd)
                WITH_CLOUDCMD=1
                ;;
            --with-apache)
                WITH_APACHE=1
                ;;
            --with-all)
                WITH_MARIADB=1
                WITH_CLOUDCMD=1
                WITH_APACHE=1
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                usage >&2
                die "Unknown option: $1"
                ;;
        esac
        shift
    done
}

main() {
    require_root
    parse_args "$@"
    load_runtime_config

    printf '\nRegulatory Voice Archive (RVA) installer\n'
    printf '========================================\n'

    if (( CHECK_ONLY )); then
        check_environment
        summary
        return $?
    fi

    if (( WITH_MARIADB )); then
        install_mariadb_component
    fi

    # Install core after MariaDB so --with-mariadb can safely create the
    # database client configuration that core would otherwise template.
    install_base_rva
    load_runtime_config

    if (( WITH_CLOUDCMD )); then
        install_cloudcmd_component
    fi

    if (( WITH_APACHE )); then
        install_apache_component
    fi

    final_validation
    check_environment
    summary
}

main "$@"
