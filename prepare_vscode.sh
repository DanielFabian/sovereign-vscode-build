#!/usr/bin/env bash
# shellcheck disable=SC1091,2154

set -e

if [[ "${VSCODE_QUALITY}" == "insider" ]]; then
  cp -rp src/insider/* vscode/
else
  cp -rp src/stable/* vscode/
fi

cp -f LICENSE vscode/LICENSE.txt

cd vscode || { echo "'vscode' dir not found"; exit 1; }

{ set +x; } 2>/dev/null

# include common variables and functions before mutating product.json
. ../utils.sh

# {{{ product.json
cp product.json{,.bak}

setpath() {
  local jsonTmp
  { set +x; } 2>/dev/null
  jsonTmp=$( jq --arg 'value' "${3}" "setpath(path(.${2}); \$value)" "${1}.json" )
  echo "${jsonTmp}" > "${1}.json"
  set -x
}

setpath_json() {
  local jsonTmp
  { set +x; } 2>/dev/null
  jsonTmp=$( jq --argjson 'value' "${3}" "setpath(path(.${2}); \$value)" "${1}.json" )
  echo "${jsonTmp}" > "${1}.json"
  set -x
}

setpath "product" "checksumFailMoreInfoUrl" "https://go.microsoft.com/fwlink/?LinkId=828886"
setpath "product" "documentationUrl" "https://go.microsoft.com/fwlink/?LinkID=533484#vscode"
setpath_json "product" "extensionsGallery" '{"serviceUrl": "https://marketplace.visualstudio.com/_apis/public/gallery", "searchUrl": "https://marketplace.visualstudio.com/_apis/public/gallery/searchrelevancy/extensionquery", "servicePPEUrl": "https://marketplace.vsallin.net/_apis/public/gallery", "cacheUrl": "https://vscode.blob.core.windows.net/gallery/index", "itemUrl": "https://marketplace.visualstudio.com/items", "publisherUrl": "https://marketplace.visualstudio.com/publishers", "resourceUrlTemplate": "https://{publisher}.vscode-unpkg.net/{publisher}/{name}/{version}/{path}", "controlUrl": "https://az764295.vo.msecnd.net/extensions/marketplace.json", "nlsBaseUrl": "https://www.vscode-unpkg.net/_lp/"}'

setpath "product" "introductoryVideosUrl" "https://go.microsoft.com/fwlink/?linkid=832146"
setpath "product" "keyboardShortcutsUrlLinux" "https://go.microsoft.com/fwlink/?linkid=832144"
setpath "product" "keyboardShortcutsUrlMac" "https://go.microsoft.com/fwlink/?linkid=832143"
setpath "product" "keyboardShortcutsUrlWin" "https://go.microsoft.com/fwlink/?linkid=832145"
setpath "product" "licenseUrl" "https://github.com/${GH_REPO_PATH}/blob/main/LICENSE"
setpath_json "product" "linkProtectionTrustedDomains" '["https://*.visualstudio.com", "https://*.microsoft.com", "https://aka.ms", "https://*.gallerycdn.vsassets.io", "https://*.github.com", "https://login.microsoftonline.com", "https://*.vscode.dev", "https://*.github.dev", "https://gh.io"]'
setpath "product" "releaseNotesUrl" "https://go.microsoft.com/fwlink/?LinkID=533483#vscode"
setpath "product" "reportIssueUrl" "https://github.com/${GH_REPO_PATH}/issues/new"
setpath "product" "requestFeatureUrl" "https://go.microsoft.com/fwlink/?LinkID=533482"
setpath "product" "tipsAndTricksUrl" "https://go.microsoft.com/fwlink/?linkid=852118"
setpath "product" "twitterUrl" "https://go.microsoft.com/fwlink/?LinkID=533687"

if [[ "${DISABLE_UPDATE}" != "yes" ]]; then
  VERSIONS_REPOSITORY="${VERSIONS_REPOSITORY:-${GH_REPO_PATH}}"
  VERSIONS_BRANCH="${VERSIONS_BRANCH:-main}"
  UPDATE_URL="${UPDATE_URL:-https://raw.githubusercontent.com/${VERSIONS_REPOSITORY}/refs/heads/${VERSIONS_BRANCH}}"
  DOWNLOAD_URL="${DOWNLOAD_URL:-https://github.com/${ASSETS_REPOSITORY}/releases}"

  setpath "product" "updateUrl" "${UPDATE_URL}"
  setpath "product" "downloadUrl" "${DOWNLOAD_URL}"

  # if [[ "${OS_NAME}" == "windows" ]]; then
  #   setpath_json "product" "win32VersionedUpdate" "true"
  # fi
fi

if [[ "${VSCODE_QUALITY}" == "insider" ]]; then
  setpath "product" "nameShort" "${APP_DISPLAY_NAME} - Insiders"
  setpath "product" "nameLong" "${APP_DISPLAY_NAME} - Insiders"
  setpath "product" "applicationName" "${BINARY_NAME}-insiders"
  setpath "product" "dataFolderName" ".${BINARY_NAME}-insiders"
  setpath "product" "linuxIconName" "${BINARY_NAME}-insiders"
  setpath "product" "quality" "insider"
  setpath "product" "urlProtocol" "vscode-insiders"
  setpath "product" "serverApplicationName" "${BINARY_NAME}-server-insiders"
  setpath "product" "serverDataFolderName" ".${BINARY_NAME}-server-insiders"
  setpath "product" "darwinBundleIdentifier" "com.vscodium.VSCodiumInsiders"
  setpath "product" "win32AppUserModelId" "VSCodium.VSCodiumInsiders"
  setpath "product" "win32DirName" "${APP_DISPLAY_NAME} Insiders"
  setpath "product" "win32MutexName" "vscodiuminsiders"
  setpath "product" "win32NameVersion" "${APP_DISPLAY_NAME} Insiders"
  setpath "product" "win32RegValueName" "SovereignCodeInsiders"
  setpath "product" "win32ShellNameShort" "${APP_DISPLAY_NAME} Insiders"
  setpath "product" "win32AppId" "{{EF35BB36-FA7E-4BB9-B7DA-D1E09F2DA9C9}"
  setpath "product" "win32x64AppId" "{{B2E0DDB2-120E-4D34-9F7E-8C688FF839A2}"
  setpath "product" "win32arm64AppId" "{{44721278-64C6-4513-BC45-D48E07830599}"
  setpath "product" "win32UserAppId" "{{ED2E5618-3E7E-4888-BF3C-A6CCC84F586F}"
  setpath "product" "win32x64UserAppId" "{{20F79D0D-A9AC-4220-9A81-CE675FFB6B41}"
  setpath "product" "win32arm64UserAppId" "{{2E362F92-14EA-455A-9ABD-3E656BBBFE71}"
  setpath "product" "tunnelApplicationName" "${BINARY_NAME}-insiders-tunnel"
  setpath "product" "win32TunnelServiceMutex" "vscodiuminsiders-tunnelservice"
  setpath "product" "win32TunnelMutex" "vscodiuminsiders-tunnel"
  setpath "product" "win32ContextMenu.x64.clsid" "90AAD229-85FD-43A3-B82D-8598A88829CF"
  setpath "product" "win32ContextMenu.arm64.clsid" "7544C31C-BDBF-4DDF-B15E-F73A46D6723D"
else
  setpath "product" "nameShort" "${APP_DISPLAY_NAME}"
  setpath "product" "nameLong" "${APP_DISPLAY_NAME}"
  setpath "product" "applicationName" "${BINARY_NAME}"
  setpath "product" "dataFolderName" ".${BINARY_NAME}"
  setpath "product" "linuxIconName" "${BINARY_NAME}"
  setpath "product" "quality" "stable"
  setpath "product" "urlProtocol" "vscode"
  setpath "product" "serverApplicationName" "${BINARY_NAME}-server"
  setpath "product" "serverDataFolderName" ".${BINARY_NAME}-server"
  setpath "product" "darwinBundleIdentifier" "com.vscodium"
  setpath "product" "win32AppUserModelId" "VSCodium.VSCodium"
  setpath "product" "win32DirName" "${APP_DISPLAY_NAME}"
  setpath "product" "win32MutexName" "vscodium"
  setpath "product" "win32NameVersion" "${APP_DISPLAY_NAME}"
  setpath "product" "win32RegValueName" "SovereignCode"
  setpath "product" "win32ShellNameShort" "${APP_DISPLAY_NAME}"
  setpath "product" "win32AppId" "{{763CBF88-25C6-4B10-952F-326AE657F16B}"
  setpath "product" "win32x64AppId" "{{88DA3577-054F-4CA1-8122-7D820494CFFB}"
  setpath "product" "win32arm64AppId" "{{67DEE444-3D04-4258-B92A-BC1F0FF2CAE4}"
  setpath "product" "win32UserAppId" "{{0FD05EB4-651E-4E78-A062-515204B47A3A}"
  setpath "product" "win32x64UserAppId" "{{2E1F05D1-C245-4562-81EE-28188DB6FD17}"
  setpath "product" "win32arm64UserAppId" "{{57FD70A5-1B8D-4875-9F40-C5553F094828}"
  setpath "product" "tunnelApplicationName" "${TUNNEL_APP_NAME}"
  setpath "product" "win32TunnelServiceMutex" "vscodium-tunnelservice"
  setpath "product" "win32TunnelMutex" "vscodium-tunnel"
  setpath "product" "win32ContextMenu.x64.clsid" "D910D5E6-B277-4F4A-BDC5-759A34EEE25D"
  setpath "product" "win32ContextMenu.arm64.clsid" "4852FC55-4A84-4EA1-9C86-D53BE3DF83C0"
fi

setpath_json "product" "tunnelApplicationConfig" '{}'

jsonTmp=$( jq -s '.[0] * .[1]' product.json ../product.json )
echo "${jsonTmp}" > product.json && unset jsonTmp

cat product.json
# }}}

# {{{ apply patches

echo "APP_NAME=\"${APP_NAME}\""
echo "APP_DISPLAY_NAME=\"${APP_DISPLAY_NAME}\""
echo "APP_NAME_LC=\"${APP_NAME_LC}\""
echo "ASSETS_REPOSITORY=\"${ASSETS_REPOSITORY}\""
echo "BINARY_NAME=\"${BINARY_NAME}\""
echo "GH_REPO_PATH=\"${GH_REPO_PATH}\""
echo "GLOBAL_DIRNAME=\"${GLOBAL_DIRNAME}\""
echo "ORG_NAME=\"${ORG_NAME}\""
echo "TUNNEL_APP_NAME=\"${TUNNEL_APP_NAME}\""

if [[ "${DISABLE_UPDATE}" == "yes" ]]; then
  mv ../patches/00-update-disable.patch.yet ../patches/00-update-disable.patch
fi

for file in ../patches/*.patch; do
  if [[ -f "${file}" ]]; then
    apply_patch "${file}"
  fi
done

if [[ "${VSCODE_QUALITY}" == "insider" ]]; then
  for file in ../patches/insider/*.patch; do
    if [[ -f "${file}" ]]; then
      apply_patch "${file}"
    fi
  done
fi

if [[ -d "../patches/${OS_NAME}/" ]]; then
  for file in "../patches/${OS_NAME}/"*.patch; do
    if [[ -f "${file}" ]]; then
      apply_patch "${file}"
    fi
  done
fi

for file in ../patches/user/*.patch; do
  if [[ -f "${file}" ]]; then
    apply_patch "${file}"
  fi
done
# }}}

set -x

# {{{ install dependencies
export ELECTRON_SKIP_BINARY_DOWNLOAD=1
export PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1

if [[ "${OS_NAME}" == "linux" ]]; then
  export VSCODE_SKIP_NODE_VERSION_CHECK=1

   if [[ "${npm_config_arch}" == "arm" ]]; then
    export npm_config_arm_version=7
  fi
elif [[ "${OS_NAME}" == "windows" ]]; then
  if [[ "${npm_config_arch}" == "arm" ]]; then
    export npm_config_arm_version=7
  fi
else
  if [[ "${CI_BUILD}" != "no" ]]; then
    clang++ --version
  fi
fi

node build/npm/preinstall.ts

mv .npmrc .npmrc.bak
cp ../npmrc .npmrc

for i in {1..5}; do # try 5 times
  if [[ "${CI_BUILD}" != "no" && "${OS_NAME}" == "osx" ]]; then
    CXX=clang++ npm ci && break
  else
    npm ci && break
  fi

  if [[ $i == 5 ]]; then
    echo "Npm install failed too many times" >&2
    exit 1
  fi
  echo "Npm install failed $i, trying again..."

  sleep $(( 15 * (i + 1)))
done

mv .npmrc.bak .npmrc
# }}}

# package.json
cp package.json{,.bak}

setpath "package" "version" "${RELEASE_VERSION%-insider}"

replace "s|Microsoft Corporation|${ORG_NAME}|" package.json

cp resources/server/manifest.json{,.bak}

if [[ "${VSCODE_QUALITY}" == "insider" ]]; then
  setpath "resources/server/manifest" "name" "${APP_DISPLAY_NAME} - Insiders"
  setpath "resources/server/manifest" "short_name" "${APP_DISPLAY_NAME} - Insiders"
else
  setpath "resources/server/manifest" "name" "${APP_DISPLAY_NAME}"
  setpath "resources/server/manifest" "short_name" "${APP_DISPLAY_NAME}"
fi

# announcements
replace "s|\\[\\/\\* BUILTIN_ANNOUNCEMENTS \\*\\/\\]|$( tr -d '\n' < ../announcements-builtin.json )|" src/vs/workbench/contrib/welcomeGettingStarted/browser/gettingStarted.ts

replace "s|Microsoft Corporation|${ORG_NAME}|" build/lib/electron.ts
replace "s|([0-9]) Microsoft|\1 ${ORG_NAME}|" build/lib/electron.ts

if [[ "${OS_NAME}" == "linux" ]]; then
  # microsoft adds their apt repo to sources
  # unless the app name is code-oss
  # as we are renaming the application to vscodium
  # we need to edit a line in the post install template
  if [[ "${VSCODE_QUALITY}" == "insider" ]]; then
    sed -i "s/code-oss/${BINARY_NAME}-insiders/" resources/linux/debian/postinst.template
  else
    sed -i "s/code-oss/${BINARY_NAME}/" resources/linux/debian/postinst.template
  fi

  # fix the packages metadata
  # code.appdata.xml
  sed -i "s|Visual Studio Code|${APP_DISPLAY_NAME}|g" resources/linux/code.appdata.xml
  sed -i "s|VSCodium|${APP_DISPLAY_NAME}|g" resources/linux/code.appdata.xml
  sed -i "s|https://code.visualstudio.com/docs/setup/linux|https://github.com/${GH_REPO_PATH}#download-install|" resources/linux/code.appdata.xml
  sed -i "s|https://code.visualstudio.com/home/home-screenshot-linux-lg.png|https://github.com/${GH_REPO_PATH}|" resources/linux/code.appdata.xml
  sed -i "s|https://www.vscodium.com|https://github.com/${GH_REPO_PATH}|g" resources/linux/code.appdata.xml
  sed -i "s|https://vscodium.com|https://github.com/${GH_REPO_PATH}|g" resources/linux/code.appdata.xml
  sed -i "s|https://code.visualstudio.com|https://github.com/${GH_REPO_PATH}|g" resources/linux/code.appdata.xml

  # control.template
  sed -i "s|Microsoft Corporation <vscode-linux@microsoft.com>|${ORG_NAME} https://github.com/${GH_REPO_PATH}/graphs/contributors|"  resources/linux/debian/control.template
  sed -i "s|VSCodium Team https://github.com/VSCodium/vscodium/graphs/contributors|${ORG_NAME} https://github.com/${GH_REPO_PATH}/graphs/contributors|" resources/linux/debian/control.template
  sed -i "s|Visual Studio Code|${APP_DISPLAY_NAME}|g" resources/linux/debian/control.template
  sed -i "s|VSCodium|${APP_DISPLAY_NAME}|g" resources/linux/debian/control.template
  sed -i "s|https://code.visualstudio.com/docs/setup/linux|https://github.com/${GH_REPO_PATH}#download-install|" resources/linux/debian/control.template
  sed -i "s|https://vscodium.com|https://github.com/${GH_REPO_PATH}|g" resources/linux/debian/control.template
  sed -i "s|https://code.visualstudio.com|https://github.com/${GH_REPO_PATH}|g" resources/linux/debian/control.template

  # code.spec.template
  sed -i "s|Microsoft Corporation|${ORG_NAME}|" resources/linux/rpm/code.spec.template
  sed -i "s|Visual Studio Code Team <vscode-linux@microsoft.com>|${ORG_NAME} https://github.com/${GH_REPO_PATH}/graphs/contributors|" resources/linux/rpm/code.spec.template
  sed -i "s|VSCodium Team https://github.com/VSCodium/vscodium/graphs/contributors|${ORG_NAME} https://github.com/${GH_REPO_PATH}/graphs/contributors|" resources/linux/rpm/code.spec.template
  sed -i "s|Visual Studio Code|${APP_DISPLAY_NAME}|" resources/linux/rpm/code.spec.template
  sed -i "s|VSCodium|${APP_DISPLAY_NAME}|" resources/linux/rpm/code.spec.template
  sed -i "s|https://code.visualstudio.com/docs/setup/linux|https://github.com/${GH_REPO_PATH}#download-install|" resources/linux/rpm/code.spec.template
  sed -i "s|https://vscodium.com|https://github.com/${GH_REPO_PATH}|g" resources/linux/rpm/code.spec.template
  sed -i "s|https://code.visualstudio.com|https://github.com/${GH_REPO_PATH}|g" resources/linux/rpm/code.spec.template

  # snapcraft.yaml
  sed -i "s|Visual Studio Code|${APP_DISPLAY_NAME}|" resources/linux/rpm/code.spec.template
elif [[ "${OS_NAME}" == "windows" ]]; then
  # code.iss
  sed -i 's|https://code.visualstudio.com|https://vscodium.com|' build/win32/code.iss
  sed -i 's|Microsoft Corporation|VSCodium|' build/win32/code.iss
fi

cd ..
