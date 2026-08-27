# Security Policy

RVA handles call metadata, packet captures, and reconstructed audio. Treat every deployment as sensitive infrastructure.

## Supported versions

Security fixes will target the latest release and the current development branch.

## Reporting a vulnerability

Do not open a public issue for vulnerabilities that could expose credentials, recordings, packet captures, database contents, or privileged access paths.

Report security issues privately to the repository owner through an appropriate private channel.

## Deployment guidance

- Keep `/etc/rva/database.cnf` readable only by the required administrative account or service.
- Do not commit credentials, internal addressing, recordings, PCAPs, TAR archives, or database dumps.
- Restrict access to `/var/spool/voipmonitor` and generated WAV files.
- Run RVA tools with the minimum privileges required.
- Keep the VoIPmonitor capture interface unnumbered unless the environment specifically requires otherwise.
- Restrict administrative tools such as Cloud Commander to trusted networks and place them behind an authenticated reverse proxy where appropriate.
- Use TLS for remote web access in production environments.
- Enable audit logging for playback and download workflows when the web portal is deployed.

## Scope

RVA does not attempt to replace the security controls of VoIPmonitor, MariaDB, the operating system, the hypervisor, or the network infrastructure. Each component must be hardened independently.
