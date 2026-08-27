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
- `xxd`
- `flock`
- ACL utilities (`setfacl`)

Useful/optional components:

- Apache HTTP Server
- Cloud Commander
- tcpdump
- rrdtool
- ethtool
- zstd
- unzip

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
