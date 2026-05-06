#!/usr/bin/env bash
# Sync upstream/stable.json with the latest tag in microsoft/vscode.
#
# We patch upstream source against a specific git tree, so the natural
# address of that tree is its git tag.  The tag is also independently
# verifiable by anyone (https://github.com/microsoft/vscode/tree/<tag>),
# unlike the update API which requires trusting a JSON endpoint.
#
# Microsoft's stable tags are pure MAJOR.MINOR.PATCH; insider builds
# are released through a different pipeline and are not tagged here, so
# this script is intentionally stable-only.
#
# Performs no git operations on this repo: callers (developer or cron)
# decide whether to commit and push.
#
# Exit codes:
#   0 - success (file may or may not have changed; check with `git diff`)
#   non-zero - upstream lookup or validation failure

set -euo pipefail

cd "$(dirname "$0")"

if [[ -n "${VSCODE_QUALITY:-}" && "${VSCODE_QUALITY}" != "stable" ]]; then
  echo "Error: track_upstream.sh is stable-only; got VSCODE_QUALITY='${VSCODE_QUALITY}'." >&2
  echo "Insider builds are not tagged in microsoft/vscode and would need a different mechanism." >&2
  exit 1
fi

upstream_repo="${UPSTREAM_REPO:-https://github.com/microsoft/vscode.git}"
upstream_file="upstream/stable.json"

# `git ls-remote` is one round-trip and gives us tag -> commit in one shot.
# We pull all refs and filter locally rather than passing a pattern, because
# we want both the strict semver filter and the highest-by-version pick.
all_refs=$(git ls-remote --tags --refs "${upstream_repo}")

ms_tag=$(
  awk '{print $2}' <<< "${all_refs}" \
    | sed 's,^refs/tags/,,' \
    | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' \
    | sort -V \
    | tail -1
)

if [[ -z "${ms_tag}" ]]; then
  echo "Error: No semver tags found in ${upstream_repo}" >&2
  exit 1
fi

ms_commit=$(awk -v ref="refs/tags/${ms_tag}" '$2 == ref { print $1 }' <<< "${all_refs}")

if [[ ! "${ms_commit}" =~ ^[0-9a-f]{40}$ ]]; then
  echo "Error: Resolved commit '${ms_commit}' for tag '${ms_tag}' is not a 40-char hex sha" >&2
  exit 1
fi

new_content=$(jq -n --arg tag "${ms_tag}" --arg commit "${ms_commit}" '{tag: $tag, commit: $commit}')

mkdir -p "$(dirname "${upstream_file}")"

if [[ -f "${upstream_file}" ]]; then
  existing_content=$(<"${upstream_file}")
  if [[ "${existing_content}" == "${new_content}" ]]; then
    echo "Upstream stable already at ${ms_tag} (${ms_commit:0:8}); ${upstream_file} unchanged."
    exit 0
  fi
fi

printf '%s\n' "${new_content}" > "${upstream_file}"
echo "Updated ${upstream_file} to ${ms_tag} (${ms_commit:0:8})."
