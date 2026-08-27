# Test Strategy

RVA should be tested with synthetic or sanitized data only. Do not commit production recordings, packet captures, telephone numbers, database dumps, or internal network details.

## v0.1.x manual validation

### Healthcheck

- Services active.
- Capture interface present and UP.
- Capture interface without an unintended IPv4 address.
- VoIPmonitor spool mounted.
- MariaDB reachable through `/etc/rva/database.cnf`.
- Recent CDR detection.
- Live traffic detection on the configured SPAN interface.
- G.729 decoder available.

### Morning check

Validate friendly labels for at least:

- answered call;
- SIP 404 / not found;
- SIP 480 / unavailable;
- SIP 486 / busy;
- SIP 487 / cancelled;
- SIP 603 / rejected.

### WAV generation

Validate at least:

- answered G.729 call with two RTP directions;
- one-way RTP call;
- call with multiple `cdr_tar_part` RTP positions;
- existing WAV without `--force`;
- forced regeneration;
- duplicate RTP sequence numbers in one direction;
- no duplicate RTP packets;
- invalid or unanswered CDR.

## RTP duplicate regression

A critical regression case is a PCAP where one RTP direction contains repeated copies of each sequence number. The reconstructed G.729 bitstream must contain only the first occurrence of each `rtp.seq` for the selected flow.

The final WAV should remain intelligible and its duration should be consistent with the actual call duration rather than expanding in proportion to duplicate packet copies.

## Future automation

Planned automated tests should use generated fixtures and mock database responses rather than real VoIPmonitor production data.
