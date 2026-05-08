# Sovereign VS Code devcontainer

This is the default **interactive / partner-mode** container for this repo.

It uses the same base image as the Linux x64 CI workflow:

- `vscodium/vscodium-linux-build-agent:focal-x64`

and layers on the two sovereign-codespaces Features we already have:

- `ghcr.io/danielfabian/sovereign-codespaces/nix-via-host:latest`
- `ghcr.io/danielfabian/sovereign-codespaces/host-ssh-keys:latest`

## Why this shape

A devcontainer is the right first boundary for day-to-day work because it keeps the VS Code build dependency stack, downloaded toolchains, generated build output, and destructive build scripts out of the host environment while preserving the normal VS Code/Copilot workflow.

The base image intentionally matches CI rather than a generic devcontainer image, because this repo's Linux build path has already been validated on `vscodium/vscodium-linux-build-agent:focal-x64`.

## Threat model

This limits blast radius, but it is **not** a hard untrusted-code sandbox.

What is intentionally isolated:

- OS packages and build dependencies live in the container image.
- Runtime Linux capabilities are dropped.
- `no-new-privileges` is set, so the default non-root user should not be able to escalate with setuid helpers.
- The Docker socket is not mounted.
- The container is not privileged.

What is intentionally shared:

- The repo checkout is bind-mounted and writable.
- Network access is available, because the build fetches upstream VS Code and dependencies.
- `/nix` is shared through `nix-via-host` for fast, host-backed tool access.
- Host SSH material is available through `host-ssh-keys` for git operations.

So: this is a good boundary for build-tool mess and accidental script damage. For truly untrusted code, remove/disable `host-ssh-keys` and consider an ephemeral `docker run --rm` flow with no credentials mounted.

## Common commands

Inside the container:

```bash
./dev/build.sh
```

For package/assets generation:

```bash
./dev/build.sh -p
```

For the narrower historical Docker-oriented helper:

```bash
./dev/build_docker.sh
```
