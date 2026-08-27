# Installation

This guide covers the RVA v0.1.x command-line toolkit. The future web portal will add separate deployment steps.

## 1. Install prerequisites

Install and configure VoIPmonitor and MariaDB first. RVA assumes VoIPmonitor is already capturing traffic and writing CDR data.

Typical additional packages include:

```bash
sudo apt update
sudo apt install -y \
  tcpdump \
  tshark \
  ffmpeg \
  rrdtool \
  ethtool \
  acl \
  zstd \
  unzip \
  vim-common
```

`vim-common` provides `xxd` on Ubuntu.

Verify G.729 support:

```bash
ffmpeg -decoders 2>/dev/null | grep -i g729
```

## 2. Create RVA configuration directory

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

## 3. Configure database access

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

## 4. Install RVA scripts

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

## 5. Validate the environment

```bash
sudo rva-healthcheck
```

The healthcheck returns:

- `0`: operational without warnings.
- `1`: operational with warnings.
- `2`: one or more failures require attention.

## 6. Daily call report

```bash
sudo rva-morning-check
```

The report shows yesterday and today using six operational columns:

```text
ID | FECHA/HORA | CALLER | CALLED | DURACION | ESTADO
```

## 7. Generate a WAV

Use the CDR ID of an answered G.729 call:

```bash
sudo rva-genera-wav 12345
```

Force regeneration when a WAV already exists:

```bash
sudo rva-genera-wav 12345 --force
```

## 8. Cloud Commander (optional)

Cloud Commander is not required by RVA. If it is installed, set `CLOUDCMD_USER` in `/etc/rva/rva.conf`. Generated WAV files will receive a read ACL for that account.

Do not expose the Cloud Commander backend port directly to untrusted networks. Prefer a restricted listener or firewall rule plus an authenticated reverse proxy.
