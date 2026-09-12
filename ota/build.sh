#!/usr/bin/env bash
# Build the OTA fork of openDAW into ota/deploy.
# Requires Node 24+. The Rust WebAssembly engine is taken prebuilt from the published npm package,
# so no Rust toolchain is needed.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

WASM_PKG_VERSION="0.0.15"

echo "== install"
npm install --no-audit --no-fund

# --force is not optional. Several package builds write generated, gitignored files OUTSIDE the
# "outputs" that turbo.json declares: studio-scripting emits src/api.declaration.d.ts and the
# scripting docs under app/studio/public/. A warm turbo cache (Vercel restores one between
# deployments) therefore reports a cache hit, restores only dist/**, and the studio build then
# fails on "Rollup failed to resolve @opendaw/studio-scripting/api.declaration?raw".
#
# Build order matters on a cold clone. app-studio is held back from the turbo pass along with
# core-wasm: turbo keeps a filtered-out package out of scope but still pulls its build into the
# task graph through dependsOn "^build", so leaving app-studio in would drag core-wasm#build back
# in and run the Rust step this build exists to avoid.
echo "== build the packages the studio app depends on"
npx turbo build --force --filter=@opendaw/app-studio... --filter=!@opendaw/studio-core-wasm --filter=!@opendaw/app-studio --output-logs=errors-only

# Take the WHOLE core-wasm dist from npm, not just the .wasm binaries. The repo's Rust source is
# ahead of the newest published build: crates/engine exports report_message_len, which the
# ${WASM_PKG_VERSION} binary does not have. Glue compiled from repo source therefore calls into a
# function the prebuilt engine lacks, and the audio engine dies with
# "report_message_len is not a function" the moment a project opens. The published glue and the
# published binary are a matched pair, so use both. vite emits dist/wasm/ under wasm-engine/ itself.
echo "== prebuilt core-wasm from npm (engine binaries and matching glue)"
TMP="$(mktemp -d)"
(cd "$TMP" && npm pack "@opendaw/studio-core-wasm@${WASM_PKG_VERSION}" >/dev/null 2>&1 && tar -xzf opendaw-studio-core-wasm-*.tgz)
rm -rf packages/studio/core-wasm/dist
mkdir -p packages/studio/core-wasm/dist
cp -r "$TMP/package/dist/." packages/studio/core-wasm/dist/
rm -rf "$TMP"

echo "== build the studio app"
(cd packages/app/studio && npm run build)

echo "== assemble deploy folder"
rm -rf ota/deploy
mkdir -p ota/deploy
cp -r packages/app/studio/dist/. ota/deploy/
find ota/deploy -type f \( -name '*.map' -o -name '*.br' \) -delete
# The ONNX runtime (26.5 MB) only serves the AI features, which this deployment does not offer.
# Removing it keeps every file under 10 MB, which static hosts handle without complaint.
find ota/deploy -type f -name 'ort-wasm-*.wasm' -delete

# The engine must be the one the glue was compiled against, or the app boots and then dies on use.
if [ ! -f ota/deploy/wasm-engine/wasm/engine.wasm ]; then
    echo "ERROR: wasm engine missing from the build output" >&2
    exit 1
fi
if grep -q "report_message_len" ota/deploy/wasm-processor.*.js 2>/dev/null; then
    echo "ERROR: glue calls report_message_len but the prebuilt engine does not export it" >&2
    exit 1
fi

echo "== done"
du -sh ota/deploy
find ota/deploy -type f | wc -l
