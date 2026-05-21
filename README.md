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

### Cấu hình thủ công (không dùng web)

- Copy `config.sh.example` → `config.sh`, đặt `TELEGRAM_TOKEN` và `TELEGRAM_CHAT_ID`.
- Các tuỳ chọn khác (hotspot mặc định, AnyDesk, …) xem trong `config.sh.example`.

### Lệnh Telegram (tóm tắt)

- `/help`, `/start`: danh sách lệnh
- `/status`: trạng thái hệ thống (chạy nền)
- `/signal`: báo cáo mạng di động (RAT/band/RSRP/RSRQ/SINR/roaming)
- `/ip`: IP local + public
- `/ping [target]`: ping (mặc định 1.1.1.1)
- `/battery`: pin
- `/datausage`: thống kê lưu lượng theo interface (realtime)
- `/sms [count]`: đọc SMS inbox (cần quyền `READ_SMS` / tùy ROM)
- `/loop_on <phút> <lệnh>` / `/loop_off`: chạy lặp theo phút
- `/rndis_on`, `/rndis_off`: USB tether (RNDIS)
- `/hotspot_on [SSID PASS]`, `/hotspot_off`: hotspot
- `/wifi_on`, `/wifi_off`: Wi‑Fi
- `/bt_on`, `/bt_off`: Bluetooth
- `/shutdown`, `/restart`: tắt máy / reboot (không spam)


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

### Manual configuration (without the website)

- Copy `config.sh.example` → `config.sh`, set `TELEGRAM_TOKEN` and `TELEGRAM_CHAT_ID`.
- See `config.sh.example` for optional settings (default hotspot, AnyDesk, …).

### Telegram commands (summary)

- `/help`, `/start`: command list
- `/status`: system status snapshot (runs in background)
- `/signal`: cellular report (RAT/band/RSRP/RSRQ/SINR/roaming)
- `/ip`: local + public IP
- `/ping [target]`: ping (default 1.1.1.1)
- `/battery`: battery info
- `/datausage`: realtime interface totals
- `/sms [count]`: read inbox SMS (requires `READ_SMS` / ROM dependent)
- `/loop_on <minutes> <command>` / `/loop_off`: scheduled loop
- `/rndis_on`, `/rndis_off`: USB tether (RNDIS)
- `/hotspot_on [SSID PASS]`, `/hotspot_off`: hotspot
- `/wifi_on`, `/wifi_off`: Wi‑Fi
- `/bt_on`, `/bt_off`: Bluetooth
- `/shutdown`, `/restart`: power off / reboot (do not spam)


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

