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

## 2026-05-05 — GitHub-hosted Linux x64 workflow succeeded

Manual workflow `linux-x64.yml` succeeded end-to-end on public standard GitHub-hosted runners in run `25375851374`. The compile job completed in 13m55s and the package job completed in 15m14s using `vscodium/vscodium-linux-build-agent:focal-x64` as the job container.

The workflow produced Linux x64 tar/deb/rpm/CLI assets and checksums as a short-retention Actions artifact. Asset sizes were larger than the Copilot-removed control build because the bundled Copilot extension and its dependencies are now preserved.

The necessary Copilot-preservation fixes were: avoid `set -u` around VSCodium scripts; remove `prepare_vscode.sh`'s direct `rm -rf extensions/copilot`; and preserve nested `.build/extensions/**/node_modules` directories in the compile-to-package transfer artifact. This proves the public GitHub-hosted runner strategy is viable for Linux x64.

## 2026-05-06 — Sovereign release version lane

The release version scheme is now a Sovereign-specific numeric lane rather than VSCodium's day/hour suffix. For upstream VS Code `major.minor.patch`, publish builds use `major.minor.(10000 + patch*100 + counter)`, where `counter` is the next available two-digit per-upstream release ordinal derived from existing GitHub release tags. Example: upstream `1.118.1`, Sovereign build 03 publishes as `1.118.10103`.

This keeps all current three-component version consumers happy while avoiding ambiguity between `patch=1,counter=23` and `patch=12,counter=3`. It also avoids relying on GitHub run ids or run numbers as product semantics. The workflow still accepts an explicit `release_version` override, but it must sit inside the current upstream tag's Sovereign lane.

## 2026-05-06 — Workflow surface pruned to Sovereign-owned CI

The old local `vscodium/` clone was removed after verifying the build repo's `vscodium-upstream` remote points at GitHub and no local path references remain.

The GitHub Actions surface was reduced to the workflows we currently own: `linux-x64.yml` for manual build/publish, `verify-publisher-app.yml` for release-environment GitHub App validation, and `lint-zizmor.yml` for workflow-file linting. Inherited VSCodium CI/publish/moderation/smoke workflows were deleted because they target old `master`/`insider` branch semantics, VSCodium release infrastructure, AUR/Snap/Winget flows, scheduled moderation, unavailable self-hosted labels, and/or the old Copilot-deleted artifact shape.
