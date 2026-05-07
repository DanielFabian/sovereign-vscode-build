export CARGO_NET_GIT_FETCH_WITH_CLI="true"
export VSCODE_CLI_APP_NAME="sovereigncode"
export VSCODE_CLI_BINARY_NAME="scode-server-insiders"
export VSCODE_CLI_DOWNLOAD_URL="https://github.com/DanielFabian/sovereign-vscode-build/releases"
export VSCODE_CLI_QUALITY="insider"
export VSCODE_CLI_UPDATE_URL="https://raw.githubusercontent.com/DanielFabian/sovereign-vscode-build/refs/heads/main"

cargo build --release --target aarch64-apple-darwin --bin=code

cp target/aarch64-apple-darwin/release/code "../../VSCode-darwin-arm64/Sovereign Code - Insiders.app/Contents/Resources/app/bin/scode-tunnel-insiders"

"../../VSCode-darwin-arm64/Sovereign Code - Insiders.app/Contents/Resources/app/bin/scode-insiders" serve-web
