# RVA Architecture

RVA is designed as an independent operational layer around VoIPmonitor rather than a replacement for the capture engine.

## Data flow

```text
Network mirror / SPAN
        |
        v
VoIPmonitor Sniffer
        |
        +--> MariaDB
        |      + CDR metadata
        |      + RTP metadata
        |      + TAR position metadata
        |
        +--> VoIPmonitor spool
               + SIP/RTP packet data
               + TAR archives
               + generated AUDIO files
                        |
                        v
                       RVA
                 + health checks
                 + daily reports
                 + WAV reconstruction
                 + future web portal
```

## Component responsibilities

### VoIPmonitor

- Packet capture and protocol processing.
- CDR creation.
- RTP metadata.
- Packet/TAR storage.

### MariaDB

RVA reads the VoIPmonitor schema. The initial toolset uses these tables:

- `cdr`
- `cdr_next`
- `cdr_rtp`
- `cdr_tar_part`

RVA joins partition-related records using both `cdr_ID` and `calldate` where required.

### `rva-genera-wav`

Reconstructs a WAV from stored RTP. The current implementation:

1. Resolves the CDR and its `fbasename`.
2. Locates the RTP TAR for the call minute.
3. Reads all RTP TAR positions belonging to the CDR.
4. Uses VoIPmonitor to reconstruct the call RTP PCAP.
5. Identifies up to two G.729 RTP directions.
6. Decodes UDP ports as RTP in TShark.
7. Deduplicates RTP packets by sequence number before concatenating G.729 payloads.
8. Decodes each direction with FFmpeg.
9. Aligns both directions using RTP `firsttime`.
10. Mixes them with `amix=duration=longest`.
11. Writes the resulting WAV to the call's `AUDIO` directory.

The RTP deduplication step protects audio reconstruction from mirrored/SPAN environments that may deliver duplicate packet copies.

### `rva-healthcheck`

Validates the runtime environment, including services, interfaces, storage, database connectivity, recent CDR activity, capture traffic, and required binaries.

### `rva-morning-check`

Shows a compact call record for yesterday and today with friendly SIP outcome labels.

## Optional Cloud Commander integration

Cloud Commander can be used as an administrative file browser for the VoIPmonitor spool. It is optional and is not intended to be the final end-user RVA interface.

The future RVA web portal will provide normal search, playback, download, role and audit workflows without requiring users to browse the raw spool.
