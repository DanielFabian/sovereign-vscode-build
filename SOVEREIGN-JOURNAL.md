# Sovereign VS Code Build Journal

## 2026-05-05 — VSCodium hard fork baseline

This repository is a vendor-hard-fork of VSCodium intended to become the private Sovereign VS Code build factory. VSCodium remains useful as an occasional upstream reference for build-break fixes, but this repo is not expected to track or rebase on VSCodium continuously.

Initial local control build used `vscodium/vscodium-linux-build-agent:focal-x64` and the unmodified VSCodium patch stack. The Linux x64 path succeeded end-to-end when run with the same substrate as VSCodium CI:

- source `get_repo.sh` locally (`. ./get_repo.sh`) so version variables survive into `build.sh`;
- run `build.sh` to produce `vscode-min-prepack`;
- create `vscode.tar.gz` artifact like the VSCodium compile job;
- run `build/linux/package_bin.sh`;
- provide Rust/rustup before `build_cli.sh` because the VSCodium image does not include Rust;
- run `prepare_assets.sh` to produce tar/deb/rpm/CLI assets and checksums.

The first reduction goal is Linux x64 only. Drop public-distribution and extra-platform semantics aggressively, but preserve a buildable path and re-add semantics deliberately.
