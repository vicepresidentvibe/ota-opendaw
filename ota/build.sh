#!/usr/bin/env bash
# Build the OTA fork of openDAW into ota/deploy.
# Requires Node 24+. The Rust WebAssembly engine is taken prebuilt from the published npm package,
# so no Rust toolchain is needed.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "== install"
npm install --no-audit --no-fund

# Three phases, and the order matters on a cold clone. core-wasm's esbuild bundle step imports
# @opendaw/studio-adapters and friends, which resolve through "./dist/index.js", so those packages
# have to be built first. The studio app in turn imports core-wasm's dist, so it has to come last.
echo "== build the packages core-wasm depends on"
npx turbo build --filter=@opendaw/studio-core-wasm... --filter=!@opendaw/studio-core-wasm --output-logs=errors-only

echo "== core-wasm: TS bundles and API only (the engine binaries come from npm below)"
(cd packages/studio/core-wasm && npm run build:bundles && npm run build:api)

echo "== build the studio app"
npx turbo build --filter=@opendaw/app-studio... --filter=!@opendaw/studio-core-wasm --output-logs=errors-only

echo "== prebuilt wasm engine from npm"
TMP="$(mktemp -d)"
(cd "$TMP" && npm pack @opendaw/studio-core-wasm@0.0.15 >/dev/null 2>&1 && tar -xzf opendaw-studio-core-wasm-*.tgz)
mkdir -p packages/app/studio/dist/wasm-engine
cp -r "$TMP/package/dist/wasm" packages/app/studio/dist/wasm-engine/
rm -rf "$TMP"

echo "== assemble deploy folder"
rm -rf ota/deploy
mkdir -p ota/deploy
cp -r packages/app/studio/dist/. ota/deploy/
find ota/deploy -type f \( -name '*.map' -o -name '*.br' \) -delete
# The ONNX runtime (26.5 MB) only serves the AI features, which this deployment does not offer.
# Removing it keeps every file under 10 MB, which static hosts handle without complaint.
find ota/deploy -type f -name 'ort-wasm-*.wasm' -delete

echo "== done"
du -sh ota/deploy
find ota/deploy -type f | wc -l
