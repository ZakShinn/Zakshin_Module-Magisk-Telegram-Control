# TelegramControl — Magisk module to control Android via Telegram

**[Tiếng Việt](#tieng-viet)** · **[English](#english)**

---

<a id="tieng-viet"></a>

## Tiếng Việt

### TelegramControl là gì?

TelegramControl là module Magisk chạy nền qua `service.sh`, long‑polling Telegram Bot API để nhận lệnh và thực thi trên thiết bị Android. Logic được tách trong `lib/*.sh` (status, signal, network, loop, …).

### Cách dùng nhanh (khuyên dùng)

- Mở website builder: **[magisk-telegram-control.vercel.app](https://magisk-telegram-control.vercel.app)**.
- Chọn ngôn ngữ hiển thị (VI/EN).
- Nhập:
  - **Chat ID**
  - **Bot token** (từ [@BotFather](https://t.me/BotFather))
- (Tuỳ chọn) bật **AnyDesk — auto media permission** nếu bạn cần.
- Tải `TelegramControl.zip`, flash trong Magisk/KernelSU, rồi **reboot**.

Sau khi cài, module chỉ nhận lệnh từ **Chat ID** bạn đã nhúng vào ZIP.

Khi có internet sau khởi động, module tự gọi Telegram `setMyCommands` để cập nhật menu lệnh (gõ `/` trong chat bot).

### Cấu hình thủ công (không dùng web)

- Copy `config.sh.example` → `config.sh`, đặt `TELEGRAM_TOKEN` và `TELEGRAM_CHAT_ID`.
- Các tuỳ chọn khác (hotspot mặc định, AnyDesk, …) xem trong `config.sh.example`.

### Lệnh Telegram (tóm tắt)

**Chính** (`/help`):

- `/status`, `/signal`, `/ip`, `/ping`, `/battery`, `/datausage`
- `/sms [count]`: đọc SMS inbox
- `/shutdown`, `/restart` (không spam)

**Nâng cao** (`/dev` — gõ `/dev`, 2 trang lệnh, ~60+ lệnh shell):

- Mạng, USB tether, hotspot, Wi‑Fi scan, DNS, interface
- Màn hình: screenshot, khóa, xoay, độ sáng, chuông, animation
- Hệ thống: CPU, nhiệt, logcat, dmesg, device info, recovery/bootloader
- App: packages, pkg, open/kill/clear, gõ text (`input`)
- SMS watch, loop, sync, GPS, DND, …


### Bảo mật

- Không công khai **Bot token** hoặc `config.sh`.

### Ủng hộ / Donate

**MB Bank:** **0968884946**

<p align="center">
  <img src="https://img.vietqr.io/image/MB-0968884946-compact.png?addTag=ZakshinTools" alt="QR VietQR MB Bank 0968884946" width="220" height="220" />
</p>

**PayPal:** [paypal.me/Zakshin](https://paypal.me/Zakshin)

<p align="center">
  <img src="./Paypal.png" alt="PayPal donate — paypal.me/Zakshin" width="220" />
</p>


---

<a id="english"></a>

## English

### What is TelegramControl?

TelegramControl is a Magisk module that runs in the background via `service.sh` and long‑polls the Telegram Bot API to receive commands and execute them on the Android device. The logic lives in `lib/*.sh` (status, signal, networking, loops, …).

### Quick start (recommended)

- Open the builder: **[magisk-telegram-control.vercel.app](https://magisk-telegram-control.vercel.app)**.
- Pick UI language (VI/EN).
- Enter:
  - **Chat ID**
  - **Bot token** (from [@BotFather](https://t.me/BotFather))
- (Optional) enable **AnyDesk — auto media permission** if needed.
- Download `TelegramControl.zip`, flash in Magisk/KernelSU, then **reboot**.

After install, the module only accepts commands from the **Chat ID** embedded in the ZIP.

When online after boot, the module calls Telegram `setMyCommands` to refresh the bot command menu (type `/` in the bot chat).

### Manual configuration (without the website)

- Copy `config.sh.example` → `config.sh`, set `TELEGRAM_TOKEN` and `TELEGRAM_CHAT_ID`.
- See `config.sh.example` for optional settings (default hotspot, AnyDesk, …).

### Telegram commands (summary)

**Main** (`/help`):

- `/status`, `/signal`, `/ip`, `/ping`, `/battery`, `/datausage`
- `/sms [count]`: read inbox SMS
- `/shutdown`, `/restart` (do not spam)

**Advanced** (`/dev` — two help messages, 60+ shell commands):

- Network, USB tether, hotspot, Wi‑Fi scan, DNS, interfaces
- Display: screenshot, lock, rotation, brightness, ringer, animations
- System: CPU, thermal, logcat, dmesg, device info, recovery/bootloader
- Apps: packages, pkg info, open/kill/clear, `input` text
- SMS watch, loops, sync, GPS, DND, …


### Security

- Never publish your **bot token** or `config.sh`.

### Donate

**MB Bank:** **0968884946**

<p align="center">
  <img src="https://img.vietqr.io/image/MB-0968884946-compact.png?addTag=ZakshinTools" alt="VietQR donate MB Bank 0968884946" width="220" height="220" />
</p>

**PayPal:** [paypal.me/Zakshin](https://paypal.me/Zakshin)

<p align="center">
  <img src="./Paypal.png" alt="PayPal donate — paypal.me/Zakshin" width="220" />
</p>

