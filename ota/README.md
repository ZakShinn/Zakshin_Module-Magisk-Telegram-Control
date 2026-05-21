# OTA Magisk (TelegramControl)

## Stable (cho phép cập nhật trong Magisk)

1. `ota/channel.json` → `"activeChannel": "stable"` và `stable.otaEnabled: true`
2. Bump `version` / `versionCode` trong `module.prop`
3. `node scripts/publish-stable-ota.mjs v4.22.0` (cập nhật `update-stable.json`)
4. `node scripts/build-ota-zip.mjs` → `dist/TelegramControl-ota.zip`
5. Tạo GitHub Release, upload ZIP, commit `ota/update-stable.json`

User: Magisk → module → **Cập nhật** (không gỡ; `config.sh` được giữ vì gói OTA không chứa `config.sh`).

## Beta (không OTA công khai)

Trước khi push code beta lên `main`:

```json
"activeChannel": "beta"
```

hoặc `"stable": { "otaEnabled": false }`

→ Module build **không** có `updateJson` → user stable không thấy bản beta trên Magisk.

Chỉ bật lại stable khi phát hành chính thức.
