# Changelog

All notable changes to Regulatory Voice Archive (RVA) will be documented in this file.

The project follows Semantic Versioning where practical.

## [Unreleased]

### Added
- Portable project bootstrap.
- Environment-independent configuration examples.
- Repository hygiene rules for sensitive voice and network artifacts.
- `install/install-prerequisites.sh` for installing and validating RVA runtime dependencies.
- `--with-prerequisites` option in `install/install.sh`.
- Modular installer options for MariaDB, Cloud Commander, and Apache.
- `--with-all` orchestration for prerequisites, MariaDB, RVA core, Cloud Commander, Apache, and final validation.
- Installer `--check` mode for non-destructive environment validation.

### Improved
- Installer output now distinguishes checks, successful actions, warnings, failures, and required manual actions.
- Installation documentation now includes direct prerequisite installation, modular component installation, and full-install examples.
- README now exposes installer flags and common installation flows.

## [0.1.0] - Planned

### Planned
- `rva-healthcheck`
- `rva-morning-check`
- `rva-genera-wav`
- G.729 audio reconstruction
- RTP duplicate suppression by sequence number
- Multi-position RTP TAR extraction
- Prerequisite checker and installer
- Modular RVA installer
- Optional MariaDB, Cloud Commander, and Apache integration
- Installation, security, architecture and troubleshooting documentation
