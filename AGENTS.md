# AGENTS.md — Agent Instructions for SOC-Shield (碳盾)

## Build & Release

### APK Build Issues

1. **INTERNET permission**: Release APK will silently fail network requests if `INTERNET` permission is missing from `android/app/src/main/AndroidManifest.xml`. Debug APK adds it automatically; Release does not.
2. **Chinese path breaks AOT**: The project path contains Chinese characters (`魏总的小项目`). Flutter's AOT snapshotter (`dart snapshot generator`) fails with exit code 255 when the path has non-ASCII characters. Copy project to a pure-ASCII path (e.g. `C:\dev\soc-app`) before `flutter build apk --release`.
3. **Proxy required**: For builds behind GFW, set `$env:HTTP_PROXY` and `$env:HTTPS_PROXY` before building.

### Release Artifacts (3 files)

| File | Source |
|------|--------|
| `soc-app-android-<version>.apk` | `build/app/outputs/flutter-apk/app-release.apk` |
| `soc-app-windows-<version>.zip` | Everything under `build/windows/x64/runner/Release/` |
| `soc-app-source-<version>.zip` | `git archive HEAD` |

## AI Feature

### API Key for Testing

```
sk-565d35ec689044799ca458896ae149a9  (DeepSeek)
```

### Preset Config

- Default provider: DeepSeek, `https://api.deepseek.com`, model `deepseek-v4-flash`
- Supports thinking mode: `thinking: {type: "enabled"}` + `reasoning_effort`
- No `max_tokens` limit (removed in v1.1.3)
- System prompt sent as `role: system`, data as `role: user`

### Known Working Endpoints

- DeepSeek: `POST https://api.deepseek.com/chat/completions` (OpenAI-compatible streaming)
- Streaming SSE: lines starting with `data: `, terminates on `data: [DONE]`

## PDF Export

- Charts rendered offscreen via `Positioned(left: 5000)` inside a `Stack(clipBehavior: Clip.none)`
- `Opacity(0)` does NOT work on Flutter 3.44.x — `toImage()` returns null
- Font: SimHei-subset.ttf (9.7MB embedded), only used for PDF generation
- App UI uses system fonts (Noto Sans SC / MiSans)
