# syntax=docker/dockerfile:1

# Keep local interactive builds on the same substrate as the Linux x64 CI jobs.
ARG BASE_IMAGE=vscodium/vscodium-linux-build-agent:focal-x64
FROM ${BASE_IMAGE}

ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=${USER_UID}

USER root

# The build-agent image carries the heavy VS Code build dependencies already.  This
# layer only makes it comfortable/safe as an interactive VS Code devcontainer:
# a stable non-root user, SSH client for git remotes, and sudo for emergency use
# if the runtime no-new-privileges guard is intentionally removed.
RUN set -eux; \
    export DEBIAN_FRONTEND=noninteractive; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        git \
        openssh-client \
        sudo; \
    rm -rf /var/lib/apt/lists/*; \
    if ! getent group "${USERNAME}" >/dev/null 2>&1; then \
        groupadd --gid "${USER_GID}" "${USERNAME}" 2>/dev/null || groupadd "${USERNAME}"; \
    fi; \
    if ! id -u "${USERNAME}" >/dev/null 2>&1; then \
        useradd \
            --uid "${USER_UID}" \
            --non-unique \
            --gid "${USERNAME}" \
            --create-home \
            --shell /bin/bash \
            "${USERNAME}"; \
    fi; \
    mkdir -p \
        "/home/${USERNAME}/.cache" \
        "/home/${USERNAME}/.cargo" \
        "/home/${USERNAME}/.npm"; \
    chown -R "${USERNAME}:${USERNAME}" "/home/${USERNAME}"; \
    echo "${USERNAME} ALL=(root) NOPASSWD:ALL" > "/etc/sudoers.d/${USERNAME}"; \
    chmod 0440 "/etc/sudoers.d/${USERNAME}"

USER ${USERNAME}
WORKDIR /workspaces/sovereign-vscode-build
