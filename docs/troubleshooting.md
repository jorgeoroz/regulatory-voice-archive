# Troubleshooting

## WAV sounds robotic or unintelligible

A mirrored/SPAN environment can deliver duplicate copies of the same RTP packet. If duplicate G.729 payloads are concatenated directly, the resulting audio can sound robotic or severely distorted.

RVA deduplicates each selected RTP flow using `rtp.seq` before reconstructing the G.729 bitstream.

To inspect duplicate sequence numbers manually:

```bash
tshark \
  -r rtp.pcap \
  -d udp.port==PORT,rtp \
  -Y 'rtp && ip.src==SOURCE_IP && udp.srcport==PORT' \
  -T fields \
  -e rtp.seq \
  | sort | uniq -c | sort -nr | head
```

Repeated counts greater than `1` indicate duplicate packet copies in the capture.

## TShark shows no RTP even though the PCAP contains UDP

TShark may not automatically classify arbitrary UDP ports as RTP. Decode the relevant ports explicitly:

```bash
tshark -r rtp.pcap \
  -d udp.port==PORT_A,rtp \
  -d udp.port==PORT_B,rtp \
  -Y rtp
```

Use the ports recorded in `cdr_rtp` for the CDR being investigated.

## `rva-genera-wav` reports no RTP positions

Verify that `cdr_tar_part` contains `type = 2` records for the exact `(cdr_ID, calldate)` pair.

The CDR-related tables can be partitioned or use composite keys; do not join only on `cdr_ID` when `calldate` is also available.

## Call was not answered

RVA intentionally refuses normal WAV generation for calls without positive `connect_duration`. There may be SIP signaling and a CDR but no useful bidirectional RTP audio.

## FFmpeg cannot decode G.729

Check:

```bash
ffmpeg -decoders 2>/dev/null | grep -i g729
```

If no G.729 decoder is listed, install a build of FFmpeg that includes G.729 decoding support.

## Cloud Commander opens but context menu/download actions are missing

Cloud Commander menu behavior depends on its configuration and version. If using Cloud Commander 19.x, verify the configured menu implementation. A deployment may use:

```json
"menu": "supermenu"
```

Restart Cloud Commander and hard-refresh the browser after changing its configuration.

Cloud Commander is optional; this does not affect the core RVA scripts.

## Apache returns `503 Service Unavailable` for Cloud Commander

A `503` from Apache usually means the reverse proxy is reachable but its backend is not.

Check:

```bash
systemctl status cloudcmd --no-pager
ss -lntp | grep 8000
curl -I http://127.0.0.1:8000/cloudcmd/
```

An unauthenticated Cloud Commander backend commonly returns `401 Unauthorized`, which is a healthy response when authentication is enabled.

## Healthcheck warns about no recent CDRs

This is an operational warning, not necessarily a platform failure. It means no new CDRs were written during `RECENT_CDR_MINUTES`.

Verify capture traffic independently with:

```bash
sudo tcpdump -ni span0 -c 10
```

Replace `span0` with the configured `SPAN_IF`.
