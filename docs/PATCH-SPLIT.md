# Patch Split Audit

This document records the first Sovereign patch-stack split. It is intentionally about semantics, not just filenames: patches stay active only when they still buy us build/update/security behavior we want to maintain.

## Current split

- Active root patches: `28` files matching `patches/*.patch`
- Inactive/reference patches: files renamed to `patches/*.patch.no`
- Validation: `python3 dev/validate-patches.py --timeout 30`
- Last validated result: all 28 active patches apply cleanly in a temporary VS Code worktree.

## Agreed product semantics

Sovereign Code is a low-maintenance VS Code-derived build with its own binary, data dirs, server dirs, update channel, and display identity, while preserving upstream service compatibility wherever possible.

Key decisions:

- Binary/application slug: `scode`
- Display name: `Sovereign Code`
- Stable data dir: `.scode`
- Stable server data dir: `.scode-server`
- Marketplace: official Visual Studio Marketplace endpoints
- Updates: release assets and `latest.json` metadata live in `DanielFabian/sovereign-vscode-build`
- Telemetry: minimize telemetry-specific patching; do not maintain VSCodium endpoint/default rewrites
- URL protocol: keep `vscode://` deliberately, even though it conflicts with vanilla VS Code, because web links and first-party auth flows treat it as a compatibility protocol rather than mere branding

## First-wave deactivations

These patches were renamed from `*.patch` to `*.patch.no`, preserving them for reference while removing them from the alphabetical apply glob.

| Patch | Decision | Rationale |
| --- | --- | --- |
| `00-build-download-extensions-from-gh.patch.no` | Drop | Restore upstream built-in extension download behavior from the configured gallery. With Marketplace configured, blocking gallery downloads is VSCodium/OpenVSX baggage. |
| `00-cloud-remove.patch.no` | Drop | Restore upstream Cloud Changes / edit-session sign-in affordances. |
| `00-community-add-announcements.patch.no` | Drop | Removes VSCodium-specific remote announcements and extra welcome-page fetches. |
| `00-copilot-fix-action-condition.patch.no` | Drop | Restores upstream Copilot/AI visibility defaults instead of hiding built-in AI features through VSCodium policy. |
| `00-ext-github-authentication-use-pat.patch.no` | Drop | Restores upstream GitHub auth support instead of forcing unsupported/PAT-like flows. |
| `00-ext-github-remove-vscodedev.patch.no` | Drop | Restores upstream `vscode.dev` / `github.dev` share and continue-working integrations. |
| `00-extension-disable-signature-verification.patch.no` | Drop | Restores extension signature verification now that Marketplace is the target gallery. |
| `00-settings-gallery.patch.no` | Drop | Removes VSCodium gallery override machinery; Marketplace endpoints are set directly in product configuration. |
| `00-telemetry-disable.patch.no` | Drop | Avoids maintaining telemetry-default surgery. This pairs with removing the `undo_telemetry.sh` call from `prepare_vscode.sh`. |
| `00-ui-disable-onboarding.patch.no` | Drop | Restores upstream welcome onboarding. |

Pre-existing inactive patches remain inactive and were not part of this first-wave decision:

- `00-build-update-electron.patch.no`
- `40-cli-use-reh-archive.patch.no`

## Active patches after first wave

These remain active for now. Several are still candidates for later reduction; they stayed active because they are build-pipeline, update-channel, packaging, security, or nontrivial dependency substitutions rather than direct FLOSS-purity removals.

| Patch | Current disposition |
| --- | --- |
| `00-binary-fix-name.patch` | Keep: binary/package naming behavior. |
| `00-brand-remove-branding.patch` | Review later: large string-scrub patch; likely reducible once product-script branding is enough. |
| `00-build-disable-esbuild.patch` | Keep for now: inherited build compatibility toggle. |
| `00-build-disable-mangle.patch` | Keep for now: inherited build compatibility toggle. |
| `00-build-fix-npm-preinstall.patch` | Keep: build fix. |
| `00-build-update-sourcemap-url.patch` | Review later: still points at VSCodium sourcemap release URLs and likely needs rewrite/drop. |
| `00-copilot-disable-terminal-suggest.patch` | Keep: adds `scode` terminal completion specs through placeholders. |
| `00-fix-non-ascii-in-prompt-regex.patch` | Keep: targeted correctness fix. |
| `00-remote-add-missing-dependencies.patch` | Keep: remote package dependency fix. |
| `00-remote-add-url.patch` | Keep: embeds REH download template for our GitHub releases. |
| `00-remote-remove-missing-vsda.patch` | Keep for now: OSS builds lack the proprietary VSDA blob; review separately. |
| `00-security-add-command-filter.patch` | Keep: security/user-control feature. |
| `00-settings-user-product.patch` | Keep: product/user configuration behavior. |
| `00-tunnel-disable-recommendation.patch` | Keep for now: review with tunnel/CLI semantics. |
| `00-ui-custom-font.patch` | Review later: large UI feature patch, not part of first-wave service restoration. |
| `00-ui-improve-eol-banner.patch` | Keep: UI improvement. |
| `00-ui-report-issue.patch` | Review later: should probably be narrowed to Sovereign issue routing. |
| `00-update-rename-cache-path.patch` | Keep: avoids Windows update cache collisions. |
| `00-vsce-use-custom-lib.patch` | Review later: VSCodium package substitution crossing signing/packaging. |
| `10-version-add-release.patch` | Keep: Sovereign version encoding/release packaging. |
| `11-update-use-github-release.patch` | Keep: update service consumes GitHub-hosted `latest.json`. |
| `12-update-add-cooldown.patch` | Keep for now: release-age cooldown. |
| `20-keymap-use-custom-lib.patch` | Review later: VSCodium native package substitution. |
| `21-policy-use-custom-lib.patch` | Review later: VSCodium policy watcher substitution. |
| `30-build-add-missing-dependencies.patch` | Keep: build dependency fix. |
| `50-build-improve-gulp-tasks.patch` | Keep: CI prepack/package split. |
| `60-security-add-option-for-malicious-ext.patch` | Keep: security/user-control feature. |
| `61-extension-close-connection.patch` | Keep: extension connection lifecycle fix. |

## Validation tooling

Use the Python validator rather than ad-hoc terminal commands:

```bash
python3 dev/validate-patches.py --list
python3 dev/validate-patches.py --timeout 30
```

The validator uses bounded `subprocess.run(..., shell=False, timeout=...)` calls and temporary git worktrees, so missing checkouts or patch failures become explicit exit codes instead of wedging an interactive terminal session.
