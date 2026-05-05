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

## 2026-05-05 — Public GitHub-hosted runners change the CI plan

GitHub's standard hosted runners are free and unlimited for public repositories. That changes the initial CI plan: the public GitHub repository should use standard GitHub-hosted runners as the primary build substrate, matching VSCodium more closely. Self-hosted TrueNAS/P620 infrastructure becomes optional fallback/cache/mirror/publisher infrastructure rather than the first build runner.

Important constraints: larger runners are still paid, even for public repositories; Actions artifacts/caches still have storage quota/billing semantics, so intermediate artifacts should use short retention and final distributables should go to GitHub Releases and/or the NAS. Public PR workflows must not receive signing or publishing secrets.
