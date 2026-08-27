# Installation

This guide covers the RVA v0.1.x command-line toolkit. The future web portal will add separate deployment steps.

RVA assumes VoIPmonitor is already installed, capturing authorized traffic, and writing CDR data. The installer is modular: it can validate the server, install runtime prerequisites, configure selected optional components, or run the complete supported flow.

## 1. Quick start

Check the server without changing anything:

```bash
sudo ./install/install.sh --check
```

Install only the RVA core files:

```bash
sudo ./install/install.sh
```

Run the complete supported installation flow:

```bash
sudo ./install/install.sh --with-all
```

The full flow runs in this order:

```text
Prerequisites
    ↓
MariaDB
    ↓
RVA Core
    ↓
Cloud Commander
    ↓
Apache
    ↓
Final validation
```

## 2. Installer options

```text
--check
    Validate the server only. Do not modify the system.

--with-prerequisites
    Install and validate the RVA runtime command-line dependencies.

--with-mariadb
    Install/enable MariaDB and prepare RVA database client access.

--with-cloudcmd
    Install/configure Cloud Commander as an optional file browser.

--with-apache
    Install/configure Apache and the Cloud Commander reverse proxy integration.

--with-all
    Run prerequisites + MariaDB + RVA core + Cloud Commander + Apache.
```

Display the current command reference directly from the installer:

```bash
sudo ./install/install.sh --help
```

Options may also be combined when a deployment needs only selected components:

```bash
sudo ./install/install.sh --with-prerequisites --with-mariadb
sudo ./install/install.sh --with-cloudcmd --with-apache
```

## 3. Runtime prerequisites

RVA includes a dedicated prerequisite installer:

```bash
sudo ./install/install-prerequisites.sh
```

Validate prerequisites without installing anything:

```bash
sudo ./install/install-prerequisites.sh --check
```

The prerequisite installer installs or validates the command-line tools required by the RVA operational scripts, including:

```text
tshark
ffmpeg
ffprobe
tcpdump
setfacl / getfacl
flock
xxd
awk
tr
ethtool
rrdtool
zstd
unzip
curl
```

Package mapping on the supported apt-based platform includes:

```text
tshark      -> tshark
ffmpeg      -> ffmpeg + ffprobe + G.729 decoder
setfacl     -> acl
flock       -> util-linux
xxd         -> xxd
awk         -> gawk
tr          -> coreutils
```

The script also verifies that FFmpeg reports a G.729 decoder:

```bash
ffmpeg -decoders 2>/dev/null | grep -i g729
```

VoIPmonitor, MariaDB, Apache, and Cloud Commander are intentionally handled separately because they have independent configuration and lifecycle requirements.

## 4. Recommended installation scenarios

### Scenario A — Existing production VoIPmonitor server

Use this when VoIPmonitor, MariaDB, and the required tools already exist:

```bash
sudo ./install/install.sh --check
sudo ./install/install.sh
sudo rva-healthcheck
```

The installer will not overwrite existing `/etc/rva` configuration files automatically.

### Scenario B — Install missing RVA tools only

```bash
sudo ./install/install.sh --with-prerequisites
```

This installs the prerequisite tools and then deploys the RVA core.

### Scenario C — Prepare RVA database access

```bash
sudo ./install/install.sh --with-mariadb
```

This installs/enables MariaDB if needed and can prepare a dedicated RVA database client account. RVA operational queries require read access to the VoIPmonitor database.

For unattended setup, the installer supports environment variables such as:

```bash
sudo RVA_DB_USER=rva \
     RVA_DB_PASSWORD='CHANGE_ME' \
     ./install/install.sh --with-mariadb
```

Do not place production passwords in the repository, shell scripts, screenshots, or documentation.

### Scenario D — Optional file browser

```bash
sudo ./install/install.sh --with-cloudcmd
```

Cloud Commander is optional. The installer creates a dedicated system account and configures it for the VoIPmonitor spool when credentials are supplied.

For unattended setup:

```bash
sudo RVA_CLOUDCMD_USERNAME=rvaadmin \
     RVA_CLOUDCMD_PASSWORD='CHANGE_ME' \
     ./install/install.sh --with-cloudcmd
```

Do not expose the Cloud Commander backend directly to untrusted networks.

### Scenario E — Apache reverse proxy

```bash
sudo ./install/install.sh --with-apache
```

If Cloud Commander is already configured, the installer enables the required Apache proxy modules and configures the `/cloudcmd/` reverse proxy using the example under `config/apache/`.

### Scenario F — Full supported deployment

```bash
sudo ./install/install.sh --with-all
```

Use this on a controlled lab or new deployment where you explicitly want RVA to install prerequisites and configure the supported optional components.

Even with `--with-all`, review the resulting configuration before exposing services to users or networks.

## 5. Manual installation path

The modular installer is recommended, but RVA can also be installed manually.

### Create the RVA configuration directory

```bash
sudo install -d -m 750 -o root -g root /etc/rva
```

Copy and edit the example configuration:

```bash
sudo cp config/rva.conf.example /etc/rva/rva.conf
sudo chown root:root /etc/rva/rva.conf
sudo chmod 640 /etc/rva/rva.conf
sudo nano /etc/rva/rva.conf
```

Set the correct administrative interface, capture interface, spool location, and optional validation values for the deployment.

### Configure database access

```bash
sudo cp config/database.cnf.example /etc/rva/database.cnf
sudo chown root:root /etc/rva/database.cnf
sudo chmod 600 /etc/rva/database.cnf
sudo nano /etc/rva/database.cnf
```

Test the credentials:

```bash
sudo mariadb \
  --defaults-extra-file=/etc/rva/database.cnf \
  --batch --skip-column-names \
  -e 'SELECT 1;'
```

Expected output:

```text
1
```

### Install RVA scripts

```bash
sudo install -m 750 -o root -g root scripts/rva-healthcheck /usr/local/sbin/rva-healthcheck
sudo install -m 750 -o root -g root scripts/rva-morning-check /usr/local/sbin/rva-morning-check
sudo install -m 750 -o root -g root scripts/rva-genera-wav /usr/local/sbin/rva-genera-wav
```

Validate shell syntax:

```bash
sudo bash -n /usr/local/sbin/rva-healthcheck
sudo bash -n /usr/local/sbin/rva-morning-check
sudo bash -n /usr/local/sbin/rva-genera-wav
```

## 6. Validate RVA

Run the operational healthcheck:

```bash
sudo rva-healthcheck
```

The healthcheck returns:

- `0`: operational without warnings.
- `1`: operational with warnings.
- `2`: one or more failures require attention.

Run the daily call report:

```bash
sudo rva-morning-check
```

The report shows yesterday and today using six operational columns:

```text
ID | FECHA/HORA | CALLER | CALLED | DURACION | ESTADO
```

Generate a WAV using the CDR ID of an answered G.729 call:

```bash
sudo rva-genera-wav 12345
```

Force regeneration when a WAV already exists:

```bash
sudo rva-genera-wav 12345 --force
```

## 7. Post-installation review

Before treating a deployment as production-ready, review at minimum:

```text
/etc/rva/rva.conf
/etc/rva/database.cnf
VoIPmonitor capture interface and spool
MariaDB permissions
Cloud Commander authentication, if enabled
Apache exposure, if enabled
Host firewall rules
Generated WAV access permissions
```

RVA does not replace deployment-specific security review, network segmentation, retention policy, backup policy, or authorization controls.
