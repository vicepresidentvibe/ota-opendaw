# OTA openDAW

A fork of [openDAW](https://github.com/andremichelle/openDAW) by André Michelle, hosted by Oregon Trail Academy for its middle school Digital Music elective.

openDAW is licensed under the GNU Affero General Public License v3 or later. This fork is published under the same license. The upstream project is unchanged except for the modifications listed below, all in this repository's history on the `ota-fork` branch.

## Modifications

### Privacy and telemetry
- Visitor count beacon removed (`boot.ts`).
- Error reports stay in the browser console and are not uploaded (`ErrorHandler.ts`).
- Live Room usage statistics are not reported (`RoomStatsReporter.ts`).
- The contributor avatar fetch from api.github.com is removed (`Contributors.tsx`).
- Community upload of samples and presets is disabled.

### Same origin
Everything the browser loads comes from this site's own hostname. Sample, preset,
soundfont and AI model requests use `/vendor-assets` and `/vendor-api`, which the host
proxies to the upstream servers (`OpenSampleAPI.ts`, `OpenSoundfontAPI.ts`,
`OpenPresetAPI.ts`, the `lib/inference` tasks).

The demo project list, the demo cover images, the demo `.odb` bundles and the Open Bundle
page were still calling `api.opendaw.studio` directly and have been routed through
`/vendor-api` as well (`DemoProjectsList.tsx`, `DemoProject.tsx`, `OpenBundlePage.tsx`).
Without that change the Demos tab failed outright and a network filter would have had to
allow a second hostname. Verified with a headless browser: zero requests leave the origin,
including after opening Demos.

Developer pages under the Help menu (Errors, Stats, Spike Test) and the public Music feed
still reference upstream servers if a user opens them. They are not loaded automatically.

### Interface
- The New Live Room and Neural Demux buttons are removed from the dashboard
  (`ActionButtons.tsx`), and "Join Live Room..." is removed from the openDAW menu
  (`StudioMenu.ts`) so the menu matches the dashboard.
- Dashboard links trimmed to the upstream site, upstream GitHub, and this fork (`Links.tsx`).
- A stub `public/sponsors.json` is shipped. Upstream generates that file outside the repo
  build, so a self hosted copy 404s on every page load without it.

### Build
The Rust WebAssembly engine is not compiled. `ota/build.sh` takes the published
`@opendaw/studio-core-wasm` package instead, so no Rust toolchain is needed.

Take the package's **entire** `dist`, not only the `.wasm` binaries. The repository's Rust
source is ahead of the newest published build: `crates/engine` exports `report_message_len`,
which the published engine does not have. Glue compiled from repo source therefore calls a
function the prebuilt engine lacks, and the audio engine dies with
`report_message_len is not a function` the moment a project is opened. The dashboard still
loads normally, so this is invisible to a boot check. The published glue and the published
binary are a matched pair. The build asserts this before finishing.

Two other things the build script has to work around, both invisible on a warm tree:
- Package build order. core-wasm's esbuild step imports workspace packages that resolve
  through `dist/index.js`, so those must be built first. app-studio is held out of the turbo
  pass as well, because a filtered-out package is still pulled into the task graph through
  `dependsOn: ["^build"]`, which would run the Rust step anyway.
- `turbo build --force` is required. `studio-scripting` writes generated, gitignored files
  outside the `outputs` its `turbo.json` entry declares. A restored turbo cache reports a hit,
  those files never reappear, and the studio build fails to resolve
  `@opendaw/studio-scripting/api.declaration?raw`.

### AI features
The AI features (Neural Demux stem separation, tempo detection, pitch to MIDI) **are**
deployed. The ONNX runtime ships as two 26.5 MB files, which takes the build output to about
99 MB.

Vercel has no per-file size limit for git-built output; its published 100 MB figure applies
to CLI source uploads. **Netlify, the fallback in `ota/netlify.toml`, does warn above 10 MB,
so moving to Netlify means deleting the `ort-wasm-*.wasm` files from the build output again
and losing these features with them.**

Bandwidth, not file size, is the real constraint. Stem separation streams a 304 MB model
through `/vendor-assets` on every use, against a 100 GB per month Vercel Hobby allowance.
Tempo detection is 11.7 MB and pitch detection is 230 kB, both harmless. One class of 25
students running stem separation once is roughly 7.6 GB.

## What this deployment stores
Nothing. There are no accounts. Projects live in the student's browser storage and can be
exported as `.odb` bundle files. No student information is collected or transmitted by this site.

## Build and hosting
See `ota/build.sh`. Host configs: `vercel.json` (repository root, primary) and
`ota/netlify.toml` (fallback). Both set the three cross origin isolation headers and proxy
`/vendor-assets` and `/vendor-api` to the upstream asset servers. The app requires
`crossOriginIsolated` to be true; if a network filter strips
`Cross-Origin-Opener-Policy` or `Cross-Origin-Embedder-Policy` in transit, the audio engine
will not start.
