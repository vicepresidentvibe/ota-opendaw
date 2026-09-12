# OTA openDAW

A fork of [openDAW](https://github.com/andremichelle/openDAW) by André Michelle, hosted by Oregon Trail Academy for its middle school Digital Music elective.

openDAW is licensed under the GNU Affero General Public License v3 or later. This fork is published under the same license. The upstream project is unchanged except for the modifications listed below, all in this repository's history on the `ota-fork` branch.

## Modifications
- Visitor count beacon removed (`boot.ts`).
- Error reports stay in the browser console and are not uploaded (`ErrorHandler.ts`).
- Live Room usage statistics are not reported (`RoomStatsReporter.ts`).
- The New Live Room and Neural Demux buttons are removed from the dashboard.
- The AI features (Neural Demux stem separation, tempo detection, pitch to MIDI) are not deployed. Their 26.5 MB runtime is removed from the build output. Choosing them from a menu will fail with an error rather than run.
- Community upload of samples and presets is disabled.
- Sample, preset, soundfont and model requests go to same origin paths (`/vendor-assets`, `/vendor-api`) which the host proxies to the upstream asset servers. The browser only ever contacts this site's hostname.
- Dashboard links trimmed to upstream site, upstream GitHub, and this fork. The contributor avatar fetch from api.github.com is removed.
- Developer pages under the Help menu (Errors, Stats, Spike Test) and the public Music feed still reference upstream servers if a user opens them. They are not loaded automatically.

## What this deployment stores
Nothing. There are no accounts. Projects live in the student's browser storage and can be exported as `.odb` bundle files. No student information is collected or transmitted by this site.

## Build and hosting
See `ota/build.sh`. Host configs: `vercel.json` (repository root, primary) and `ota/netlify.toml` (fallback). Both set the three cross origin isolation headers and proxy `/vendor-assets` and `/vendor-api` to the upstream asset servers.
