#!/usr/bin/env bash
# shellcheck disable=SC2129

set -e

ASSETS_REPOSITORY="${ASSETS_REPOSITORY:-}"
CI_BUILD="${CI_BUILD:-yes}"
GH_HOST="${GH_HOST:-github.com}"
GITHUB_ENV="${GITHUB_ENV:-}"
MS_COMMIT="${MS_COMMIT:-}"
MS_TAG="${MS_TAG:-}"
RELEASE_VERSION="${RELEASE_VERSION:-}"
SOVEREIGN_RELEASE_REPOSITORY="${SOVEREIGN_RELEASE_REPOSITORY:-}"
SOVEREIGN_RELEASE_TAGS="${SOVEREIGN_RELEASE_TAGS:-}"
VSCODE_LATEST="${VSCODE_LATEST:-}"
VSCODE_QUALITY="${VSCODE_QUALITY:-stable}"

# git workaround
if [[ "${CI_BUILD}" != "no" && -n "${GITHUB_REPOSITORY:-}" ]]; then
  git config --global --add safe.directory "/__w/$( echo "${GITHUB_REPOSITORY}" | awk '{print tolower($0)}' )"
fi

SOVEREIGN_RELEASE_BASE="${SOVEREIGN_RELEASE_BASE:-10000}"
SOVEREIGN_RELEASE_SLOT_SIZE="${SOVEREIGN_RELEASE_SLOT_SIZE:-100}"

parseSemver() {
  local label version

  label="${1}"
  version="${2%-insider}"

  if [[ ! "${version}" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
    echo "Error: Bad ${label}: ${2}"
    exit 1
  fi

  SEMVER_MAJOR="${BASH_REMATCH[1]}"
  SEMVER_MINOR="${BASH_REMATCH[2]}"
  SEMVER_PATCH="${BASH_REMATCH[3]}"
}

listSovereignReleaseTags() {
  local releaseRepository releaseHost releaseRefs

  if [[ -n "${SOVEREIGN_RELEASE_TAGS}" ]]; then
    printf '%s\n' "${SOVEREIGN_RELEASE_TAGS}"
    return 0
  fi

  releaseRepository="${SOVEREIGN_RELEASE_REPOSITORY:-${ASSETS_REPOSITORY}}"

  if [[ -z "${releaseRepository}" ]]; then
    echo "No ASSETS_REPOSITORY defined; assuming no existing Sovereign release tags" >&2
    return 0
  fi

  releaseHost="${GH_HOST}"

  if ! releaseRefs=$( git ls-remote --tags --refs "https://${releaseHost}/${releaseRepository}.git" "refs/tags/${MS_MAJOR}.${MS_MINOR}.*" ); then
    echo "Error: Failed to list release tags from ${releaseRepository}"
    exit 1
  fi

  awk '{ sub("refs/tags/", "", $2); print $2 }' <<< "${releaseRefs}"
}

deriveSovereignReleaseVersion() {
  local maxCounter nextCounter laneBase laneLimit encodedPatch counter tag releaseVersionPattern

  parseSemver "MS_TAG" "${MS_TAG}"
  MS_MAJOR="${SEMVER_MAJOR}"
  MS_MINOR="${SEMVER_MINOR}"
  MS_PATCH="${SEMVER_PATCH}"

  laneBase=$(( SOVEREIGN_RELEASE_BASE + (10#${MS_PATCH} * SOVEREIGN_RELEASE_SLOT_SIZE) ))
  laneLimit=$(( laneBase + SOVEREIGN_RELEASE_SLOT_SIZE ))
  maxCounter=0

  if [[ "${VSCODE_QUALITY}" == "insider" ]]; then
    releaseVersionPattern="^${MS_MAJOR}\\.${MS_MINOR}\\.([0-9]+)-insider$"
  else
    releaseVersionPattern="^${MS_MAJOR}\\.${MS_MINOR}\\.([0-9]+)$"
  fi

  while IFS= read -r tag; do
    tag="${tag#refs/tags/}"

    if [[ "${tag}" =~ ${releaseVersionPattern} ]]; then
      encodedPatch=$((10#${BASH_REMATCH[1]}))

      if (( encodedPatch > laneBase && encodedPatch < laneLimit )); then
        counter=$(( encodedPatch - laneBase ))

        if (( counter > maxCounter )); then
          maxCounter="${counter}"
        fi
      fi
    fi
  done < <(listSovereignReleaseTags)

  nextCounter=$(( maxCounter + 1 ))

  if (( nextCounter >= SOVEREIGN_RELEASE_SLOT_SIZE )); then
    echo "Error: Too many Sovereign releases for ${MS_TAG}; counter ${nextCounter} exceeds $((SOVEREIGN_RELEASE_SLOT_SIZE - 1))"
    exit 1
  fi

  encodedPatch=$(( laneBase + nextCounter ))

  if [[ "${VSCODE_QUALITY}" == "insider" ]]; then
    RELEASE_VERSION="${MS_MAJOR}.${MS_MINOR}.${encodedPatch}-insider"
  else
    RELEASE_VERSION="${MS_MAJOR}.${MS_MINOR}.${encodedPatch}"
  fi

  echo "SOVEREIGN_RELEASE_COUNTER=${nextCounter}"
}

validateSovereignReleaseVersion() {
  local encodedPatch laneBase laneLimit counter

  parseSemver "MS_TAG" "${MS_TAG}"
  MS_MAJOR="${SEMVER_MAJOR}"
  MS_MINOR="${SEMVER_MINOR}"
  MS_PATCH="${SEMVER_PATCH}"

  if [[ "${VSCODE_QUALITY}" == "insider" ]]; then
    if [[ "${RELEASE_VERSION}" != *-insider ]]; then
      echo "Error: Bad RELEASE_VERSION for insider build: ${RELEASE_VERSION}"
      exit 1
    fi
  elif [[ "${RELEASE_VERSION}" == *-insider ]]; then
    echo "Error: Bad RELEASE_VERSION for stable build: ${RELEASE_VERSION}"
    exit 1
  fi

  parseSemver "RELEASE_VERSION" "${RELEASE_VERSION}"

  if [[ "${SEMVER_MAJOR}" != "${MS_MAJOR}" || "${SEMVER_MINOR}" != "${MS_MINOR}" ]]; then
    echo "Error: RELEASE_VERSION ${RELEASE_VERSION} does not match upstream ${MS_TAG} major/minor"
    exit 1
  fi

  laneBase=$(( SOVEREIGN_RELEASE_BASE + (10#${MS_PATCH} * SOVEREIGN_RELEASE_SLOT_SIZE) ))
  laneLimit=$(( laneBase + SOVEREIGN_RELEASE_SLOT_SIZE ))
  encodedPatch=$((10#${SEMVER_PATCH}))

  if (( encodedPatch <= laneBase || encodedPatch >= laneLimit )); then
    echo "Error: RELEASE_VERSION ${RELEASE_VERSION} is outside the Sovereign lane for ${MS_TAG}: ${MS_MAJOR}.${MS_MINOR}.$((laneBase + 1)) through ${MS_MAJOR}.${MS_MINOR}.$((laneLimit - 1))"
    exit 1
  fi

  counter=$(( encodedPatch - laneBase ))
  echo "SOVEREIGN_RELEASE_COUNTER=${counter}"
}

if [[ "${VSCODE_LATEST}" == "yes" ]] || [[ ! -f "./upstream/${VSCODE_QUALITY}.json" ]]; then
  echo "Retrieve latest version"
  UPDATE_INFO=$( curl --silent --fail "https://update.code.visualstudio.com/api/update/darwin/${VSCODE_QUALITY}/0000000000000000000000000000000000000000" )
else
  echo "Get version from ${VSCODE_QUALITY}.json"
  MS_COMMIT=$( jq -r '.commit' "./upstream/${VSCODE_QUALITY}.json" )
  MS_TAG=$( jq -r '.tag' "./upstream/${VSCODE_QUALITY}.json" )
fi

if [[ -z "${MS_COMMIT}" ]]; then
  MS_COMMIT=$( echo "${UPDATE_INFO}" | jq -r '.version' )
  MS_TAG=$( echo "${UPDATE_INFO}" | jq -r '.name' )

  if [[ "${VSCODE_QUALITY}" == "insider" ]]; then
    MS_TAG="${MS_TAG/\-insider/}"
  fi
fi

if [[ -z "${RELEASE_VERSION}" ]]; then
  deriveSovereignReleaseVersion
else
  validateSovereignReleaseVersion
fi

echo "RELEASE_VERSION=\"${RELEASE_VERSION}\""

if [[ "${SOVEREIGN_RESOLVE_VERSION_ONLY}" == "yes" ]]; then
  export MS_TAG
  export MS_COMMIT
  export RELEASE_VERSION
  return 0 2>/dev/null || exit 0
fi

mkdir -p vscode
cd vscode || { echo "'vscode' dir not found"; exit 1; }

git init -q
git remote add origin https://github.com/Microsoft/vscode.git

# figure out latest tag by calling MS update API
if [[ -z "${MS_TAG}" ]]; then
  UPDATE_INFO=$( curl --silent --fail "https://update.code.visualstudio.com/api/update/darwin/${VSCODE_QUALITY}/0000000000000000000000000000000000000000" )
  MS_COMMIT=$( echo "${UPDATE_INFO}" | jq -r '.version' )
  MS_TAG=$( echo "${UPDATE_INFO}" | jq -r '.name' )
elif [[ -z "${MS_COMMIT}" ]]; then
  REFERENCE=$( git ls-remote --tags | grep -x ".*refs\/tags\/${MS_TAG}" | head -1 )

  if [[ -z "${REFERENCE}" ]]; then
    echo "Error: The following tag can't be found: ${MS_TAG}"
    exit 1
  elif [[ "${REFERENCE}" =~ ^([[:alnum:]]+)[[:space:]]+refs\/tags\/([0-9]+\.[0-9]+\.[0-9]+)$ ]]; then
    MS_COMMIT="${BASH_REMATCH[1]}"
    MS_TAG="${BASH_REMATCH[2]}"
  else
    echo "Error: The following reference can't be parsed: ${REFERENCE}"
    exit 1
  fi
fi

echo "MS_TAG=\"${MS_TAG}\""
echo "MS_COMMIT=\"${MS_COMMIT}\""

git fetch --depth 1 origin "${MS_COMMIT}"
git checkout FETCH_HEAD

cd ..

# for GH actions
if [[ "${GITHUB_ENV}" ]]; then
  echo "MS_TAG=${MS_TAG}" >> "${GITHUB_ENV}"
  echo "MS_COMMIT=${MS_COMMIT}" >> "${GITHUB_ENV}"
  echo "RELEASE_VERSION=${RELEASE_VERSION}" >> "${GITHUB_ENV}"
fi

export MS_TAG
export MS_COMMIT
export RELEASE_VERSION
