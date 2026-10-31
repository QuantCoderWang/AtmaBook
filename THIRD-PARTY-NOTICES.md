# Third-Party Notices / 第三方组件许可说明 — AtmaBook

> AtmaBook — Offline Travel Guide Mapbook / 离线旅行攻略地图本
> Copyright 2026 WangYuwen (AtmaBook project)
>
> The project's own code (lib/ · test/ · platform scaffolding · docs · installer script) is licensed under the **Apache License, Version 2.0** — see the root [`LICENSE`](LICENSE) file.
> 本项目自研代码以 **Apache License 2.0** 发布（见根目录 [`LICENSE`](LICENSE)）。
>
> All third-party components listed below remain under their own licenses; this file inventories them with the obligations each carries. License facts verified against the local Pub cache and upstream repositories (2026-10-28 snapshot); re-verify on dependency upgrades.
> 下列第三方组件依其自身许可证发布，本文件逐件汇总署名与义务。许可信息核对自本机 Pub 缓存与上游官方仓库（2026-10-28 快照）；依赖升级后需复核。

---

## 1. Application framework / 应用框架

| Component | Version | License | Role |
| --- | --- | --- | --- |
| Flutter SDK | 3.47 stable | BSD-3-Clause | UI framework / rendering engine / build toolchain |
| Flutter platform templates (windows/runner C++, Android templates) | — | BSD-3-Clause (same family) | window host, platform channels |

- The Flutter engine aggregates many additional third-party works; when distributing builds, surface them via Flutter's built-in `LicensePage` or an aggregated NOTICES listing.
- The local SDK carries three in-house framework patches (semantics.dart / rendering/object.dart, derived from upstream Flutter PRs). Patches are derivatives of BSD-3 Flutter code: no obligations beyond the standard BSD-3 notices.
- Flutter 引擎聚合了大量第三方件，正式分发时请用 Flutter 自带的 `LicensePage`（或聚合清单）一并呈现；本地 SDK 三枚框架补丁派生自 BSD-3 的 Flutter 代码，无 BSD-3 之外的附加义务。

## 2. Dart dependencies / Dart 直接依赖（pubspec.yaml）

| Package | Version | License | Role |
| --- | --- | --- | --- |
| flutter_localizations | sdk | BSD-3 | Material/Cupertino localization strings |
| intl | ^0.20.2 | BSD-3 | l10n generation chain |
| provider | ^6.1.5+1 | MIT | global state management |
| latlong2 | ^0.10.1 | Apache-2.0 | lat/lng coordinate types |
| flutter_map | ^8.3.2 | BSD-3-Clause | map rendering engine |
| http | ^1.6.0 | BSD-3 | HTTP client (geocoding, tile download) |
| path_provider | ^2.1.6 | BSD-3 | cross-platform app directories |
| shared_preferences | ^2.5.6 | BSD-3 | key-value settings persistence |
| image | ^4.12.0 | MIT | image decode/encode |
| url_launcher | ^6.3.3 | BSD-3 | external link opening |
| image_picker | ^1.2.4 | BSD-3 | system gallery/camera picking |
| geolocator | ^14.1.2 | MIT | device location |
| archive | ^4.0.0 | MIT | zip engine (share packs) |
| file_selector | ^1.0.3 | BSD-3 | native file dialogs |
| media_kit | ^1.2.6 | MIT | video playback core (Dart layer) |
| media_kit_video | ^2.0.1 | MIT | video playback UI layer |
| media_kit_libs_windows_video | ^1.0.11 | MIT (package) + bundled native binaries, see §3 | Windows native video libs |
| media_kit_libs_android_video | ^1.3.8 | MIT (package) + bundled native binaries, see §3 | Android native video libs |
| media_kit_libs_ios_video | ^1.1.4 | MIT (package) + bundled native binaries, see §3 | iOS native video libs |
| media_kit_libs_linux | ^1.2.1 | MIT (package) + bundled native binaries, see §3 | Linux native video libs |

All of the above permit commercial use and redistribution provided their copyright/license notices are retained. / 以上全部允许商用与再分发，义务为保留各自版权与许可声明。

## 3. ⚠ Bundled native media binaries / 随包原生媒体二进制（GPL family）

`media_kit_libs_*` Dart packages are MIT-licensed, but the native decode/render binaries they install are **not**:

- **mpv / libmpv** — GPLv2+ (or later);
- **FFmpeg** (compiled inside libmpv) — LGPL/GPL depending on build configuration.

Obligations when distributing builds that include these binaries / 分发含这些二进制的构建时：

1. Include the corresponding license texts (mpv, FFmpeg, and the media-kit native repo's own `THIRD-PARTY-LICENSES` inventory) in the app's about/licenses page or a bundled notices file;
2. Provide pointers to the corresponding source code (mpv: [mpv.io](https://mpv.io) / [github.com/mpv-player/mpv](https://github.com/mpv-player/mpv); FFmpeg: [ffmpeg.org](https://www.ffmpeg.org); native builds: [github.com/media-kit/media-kit](https://github.com/media-kit/media-kit) — verify the exact build used at release time);
3. Note: libmpv is loaded via `dart:ffi` (runtime dynamic loading). Whether dynamic loading constitutes "linking" for GPL purposes is a debated gray zone; industry practice treats the binary layer as a separate work, but closed-source commercial distribution should obtain a formal legal opinion or replace the component.

/ 义务：①应用内随附 mpv/FFmpeg 许可文本与 media-kit 原生库清单；②给出对应源码获取途径；③libmpv 经 dart:ffi 动态加载处于法律灰区，闭源商用前建议取得正式法律意见或更换组件。

## 4. ⚠ User-provided FFmpeg runtime / 用户自备 FFmpeg 运行时（`ffmpeg_runtime/`）

`ffmpeg.exe` / `ffprobe.exe` are **not included in this repository** (each exceeds GitHub's file limit); users obtain a GPL build (with libx264, e.g. gyan.dev `release-full` or BtbN `win64-gpl`) themselves. The app invokes them as **separate processes** (`Process.run`) — no binary linkage with the app code.

- If **you** distribute these executables with your build, GPL redistribution terms apply to them (license text + corresponding-source offer for that build). / 若分发方随包再分发这两个 exe，须按 GPL 履行许可文本随附与源码提供义务；
- If the **user** downloads them (as this repository's README instructs), the redistribution obligation shifts to the user. / 若按本仓库 README 的指引由用户自行下载，再分发义务由用户自担；
- Switching to an LGPL build (e.g. BtbN `ffmpeg-*-lgpl`) removes libx264 (H.264 encoding) but downgrades obligations to "attach license text + source link" only. / 换 LGPL 构建可把义务降为“仅随附许可文本 + 源码链接”，代价是失去 libx264 的 H.264 编码。

## 5. Map data and services / 地图数据与外部服务（runtime only, not bundled / 运行时调用，不进安装包）

| Source | Terms | Obligations |
| --- | --- | --- |
| OpenStreetMap tiles | ODbL (database) + CC-BY-SA content | Mandatory attribution: **"© OpenStreetMap contributors"** must be displayable in the UI, for both online and offline tiles / 必须在界面可展示该署名（在线与离线瓦片均适用） |
| Nominatim (geocoding) | public service usage policy | rate limits, custom User-Agent (shipped), no bulk crawling; at commercial scale, self-host or use a commercial provider / 限频与禁批量；规模化商用需自建或换商业服务 |
| AMap / Tianditu tiles & search | provider terms (optional keys) | personal keys ≠ commercial license; commercial use requires provider agreements / 个人 key 非商用授权，商用须与供应商签约 |
| Esri tiles | provider terms | attribution as labeled in-app / 按应用内标注署名 |
| OSRM (routing) | demo service | demo is for testing only; production/commercial routing requires self-hosting / Demo 仅供测试，生产商用须自部署 |

## 6. Build-time tools / 构建期工具（not shipped in artifacts / 不进产物）

- Gradle / Android SDK / NDK — Apache-2.0 family;
- NuGet — flutter toolchain's build-time fetch;
- flutter_launcher_icons — MIT (dev dependency);
- flutter_lints — BSD-3 (dev dependency);
- Inno Setup (Windows installer packaging via `installer.iss`) — Inno Setup License, free for commercial use.

## 7. Assets / 资产

Application icons and all artwork under `assets/` are original to this project. / `assets/` 内图标与全部美术资源为本项目原创。

---

> **Disclaimer / 免责声明**：本文件为许可事实汇总与义务提示，不构成法律意见；商业分发前请以各许可证原文为准，必要时咨询法律专业人士。
> This file is an informational inventory, not legal advice; consult the license texts (and counsel, for commercial distribution) as authoritative.
