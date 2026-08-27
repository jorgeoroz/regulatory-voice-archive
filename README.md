# Regulatory Voice Archive (RVA)

RVA is an independent open-source project built to integrate with VoIPmonitor. It is not affiliated with or endorsed by VoIPmonitor.

RVA adds an operational and user-facing layer on top of VoIPmonitor for call review, audio reconstruction, health checks, reporting, and future web-based search/playback workflows.

## Current scope — v0.1.0

- VoIPmonitor integration
- G.729 WAV reconstruction from stored RTP
- RTP duplicate suppression using RTP sequence numbers
- Support for RTP stored across multiple TAR positions
- Daily call report for today and yesterday
- System and service health checks
- Optional Cloud Commander integration
- Portable configuration under `/etc/rva`
- Modular installer with prerequisite, MariaDB, Cloud Commander, and Apache options
- Installation and hardening documentation

## Planned scope — v0.2.0

- Web search by date, caller, called number, extension, duration, and SIP status
- In-browser playback
- Controlled downloads
- Authentication and roles
- Audit trail for searches, playback, and downloads
- Friendly SIP status descriptions

## Architecture

```text
SPAN / mirror traffic
        |
        v
  VoIPmonitor Sniffer
        |
        +--> MariaDB (CDR metadata)
        |
        +--> /var/spool/voipmonitor (PCAP/TAR data)
                         |
                         v
                     RVA tools
                + healthcheck
                + morning report
                + WAV generator
                + future web portal
```

## Requirements

Core requirements:

- Linux (Ubuntu Server is the primary tested platform)
- VoIPmonitor Sniffer
- MariaDB client/server compatible with the VoIPmonitor schema
- Bash
- TShark
- FFmpeg with G.729 decoder support
- tcpdump
- `xxd`
- `flock`
- ACL utilities (`setfacl`)

Useful/optional components:

- Apache HTTP Server
- Cloud Commander
- rrdtool
- ethtool
- zstd
- unzip

## Installation

RVA provides a modular installer so administrators can validate the environment first and opt in only to the components they want RVA to configure.

Check the server without making changes:

```bash
sudo ./install/install.sh --check
```

Install only the RVA core files:

```bash
sudo ./install/install.sh
```

Install and validate runtime prerequisites:

```bash
sudo ./install/install.sh --with-prerequisites
```

Install individual optional components:

```bash
sudo ./install/install.sh --with-mariadb
sudo ./install/install.sh --with-cloudcmd
sudo ./install/install.sh --with-apache
```

Run the full supported installation flow:

```bash
sudo ./install/install.sh --with-all
```

`--with-all` runs the installation in this order:

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

### Installer options

| Option | Purpose |
| --- | --- |
| `--check` | Validate the server only. No configuration changes are made. |
| `--with-prerequisites` | Install and validate RVA runtime tools such as TShark, FFmpeg/FFprobe, tcpdump, ACL utilities, `flock`, `xxd`, rrdtool, ethtool, zstd, unzip, and related command-line dependencies. |
| `--with-mariadb` | Install/enable MariaDB and prepare RVA database client access. |
| `--with-cloudcmd` | Install/configure Cloud Commander as an optional file browser. |
| `--with-apache` | Install/configure Apache and the Cloud Commander reverse proxy integration. |
| `--with-all` | Run prerequisites + MariaDB + RVA core + Cloud Commander + Apache + final validation. |

The prerequisite installer can also be run directly:

```bash
sudo ./install/install-prerequisites.sh --check
sudo ./install/install-prerequisites.sh
```

Use the built-in help for the current command reference:

```bash
sudo ./install/install.sh --help
```

See `docs/installation.md` for the complete installation guide and manual installation path.

## Configuration

RVA is designed to avoid environment-specific values in the scripts. Runtime configuration belongs in:

```text
/etc/rva/rva.conf
/etc/rva/database.cnf
```

Example files are provided under `config/`.

Do **not** commit production credentials, call recordings, packet captures, database dumps, internal IP addresses, or organization-specific configuration.

## Repository layout

```text
config/     Example runtime configuration
docs/       Architecture, installation, security and troubleshooting documentation
install/    Prerequisite checks and installation helpers
scripts/    RVA operational tools
tests/      Test notes and future automated validation
```

## Security

RVA processes potentially sensitive voice and call metadata. Deploy it only on systems and networks that are authorized to capture and retain this traffic. Keep database credentials outside the repository and restrict access to generated audio.

See `SECURITY.md` for reporting and deployment guidance.

## License

Apache License 2.0. See `LICENSE`.
