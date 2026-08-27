# Prerequisites

RVA v0.1.x is an integration toolkit. It assumes a working VoIPmonitor deployment rather than installing or configuring the packet-capture engine itself.

## Required

- Linux host capable of running VoIPmonitor.
- VoIPmonitor Sniffer configured and writing CDR data.
- MariaDB-compatible VoIPmonitor database.
- Bash.
- TShark.
- FFmpeg and FFprobe with G.729 decode support.
- `tcpdump` for capture validation.
- `setfacl` for optional file-browser read access.
- `flock` for per-CDR generation locking.
- `xxd`, `awk`, and standard GNU userland tools.

## Optional

- Apache HTTP Server for reverse proxy and the future web portal.
- Cloud Commander as an administrative spool browser.
- nftables or another host firewall.
- rrdtool, ethtool, zstd, unzip for operational support.

## VoIPmonitor schema expectations

The initial RVA scripts read:

- `cdr`
- `cdr_next`
- `cdr_rtp`
- `cdr_tar_part`

The WAV generator expects RTP metadata and stored RTP packet data for answered G.729 calls.

## Storage expectations

By default, RVA expects the VoIPmonitor spool at:

```text
/var/spool/voipmonitor
```

This is configurable in `/etc/rva/rva.conf`.

## Permissions

The operational scripts are intended for installation under `/usr/local/sbin` and normal execution with `sudo` because they may need to:

- read protected VoIPmonitor packet archives;
- create audio files under the spool;
- grant an optional read ACL to a file-browser service account;
- inspect system services and capture interfaces.

Database credentials must be stored outside the repository in `/etc/rva/database.cnf` with restrictive filesystem permissions.
