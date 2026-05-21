export type Lang = "vi" | "en";

export const STR = {
  vi: {
    skipToContent: "Bỏ qua đến nội dung",
    brandName: "TelegramControl",
    brandHomeAria: "TelegramControl — về trang chủ",
    siteKeywordsLine: "Magisk · Telegram · Android",
    heroEyebrow: "",
    mastheadNavAria: "Giao diện và ngôn ngữ",
    themeGroupAria: "Chế độ giao diện",
    langGroupAria: "Ngôn ngữ hiển thị",
    formSectionTitle: "Cấu hình & tải Module Magisk",
    donateBankLabel: "Ngân hàng",
    donateQrAlt:
      "Mã QR VietQR ủng hộ — MB Bank 0968884946 — Võ Hoàng Hải Nghĩa",
    donatePaypalLabel: "PayPal",
    title: "TelegramControl · Builder ZIP module",
    lead:
      "Nhập Bot Token và Chat ID để tạo file ZIP module Magisk đã nhúng config.sh. Tải về và flash trong Magisk như module thông thường.",
    tokenLabel: "Bot token (@BotFather)",
    chatLabel: "Chat ID",
    chatPh: "-100xxxxxxxx hoặc số User ID",
    hotspotFieldsetLegend: "Hotspot mặc định (/hotspot_on không thêm đối số)",
    hotspotSsidLabel: "Tên Wi‑Fi (SSID)",
    hotspotSsidPh: "Để trống = Hotspot",
    hotspotPassLabel: "Mật khẩu Wi‑Fi",
    hotspotPassPh: "Để trống = 12345678",
    hotspotPassShow: "Hiện",
    hotspotPassHide: "Ẩn",
    hotspotPassShowAria: "Hiện mật khẩu Wi‑Fi",
    hotspotPassHideAria: "Ẩn mật khẩu Wi‑Fi",
    hotspotHint:
      "SSID và mật khẩu đều phân biệt chữ hoa/thường — nhập đúng từng ký tự. Khi gõ /hotspot_on không kèm tên/mật khẩu, module dùng các giá trị nhập ở đây (hoặc mặc định Hotspot / 12345678 nếu để trống).",
    anydeskAutoMediaLabel:
      "Tự động cấp quyền media cho AnyDesk (PROJECT_MEDIA) — mặc định tắt, tích để bật.",
    submit: "Tải TelegramControl.zip",
    submitting: "Đang đóng gói…",
    hint:
      "Sau khi cài và khởi động lại: chỉ Chat ID đã nhập mới có quyền điều khiển bot.",
    testedDevicesNote:
      "Đã test và chạy tốt trên thiết bị Samsung Galaxy Z Flip4 và Samsung Galaxy Z Fold4. Một số thiết bị có thể không tương thích.",
    errNetwork: "Không tải được — kiểm tra mạng hoặc thử lại.",
    errContactHint: "Nếu vẫn gặp lỗi hoặc cần hỗ trợ:",
    errContactLink: "liên hệ qua Facebook",
    themeDark: "Tối",
    themeLight: "Sáng",
    langVi: "Tiếng Việt",
    langEn: "English",
    donateTitle: "Ủng hộ",
    donateRecipient: "Võ Hoàng Hải Nghĩa",
    donateBankName: "Ngân hàng MB",
    contactFacebook: "Liên hệ · Báo lỗi (Facebook)",
    donatePaypal: "Donate · PayPal",
  },
  en: {
    skipToContent: "Skip to content",
    brandName: "TelegramControl",
    brandHomeAria: "TelegramControl — home",
    siteKeywordsLine: "Magisk · Telegram · Android",
    heroEyebrow: "",
    mastheadNavAria: "Appearance and language",
    themeGroupAria: "Theme",
    langGroupAria: "Language",
    formSectionTitle: "Configure & download Module Magisk",
    donateBankLabel: "Bank",
    donateQrAlt:
      "VietQR donate — MB Bank 0968884946 — Vo Hoang Hai Nghia",
    donatePaypalLabel: "PayPal",
    title: "TelegramControl · Magisk ZIP builder",
    lead:
      "Enter your Bot Token and Chat ID to build a Magisk module ZIP with embedded config.sh. Download and flash in Magisk as usual.",
    tokenLabel: "Bot token (@BotFather)",
    chatLabel: "Chat ID",
    chatPh: "-100xxxxxxxx or numeric user ID",
    hotspotFieldsetLegend: "Default hotspot (plain /hotspot_on with no arguments)",
    hotspotSsidLabel: "Wi‑Fi name (SSID)",
    hotspotSsidPh: "Leave empty for Hotspot",
    hotspotPassLabel: "Wi‑Fi password",
    hotspotPassPh: "Leave empty for 12345678",
    hotspotPassShow: "Show",
    hotspotPassHide: "Hide",
    hotspotPassShowAria: "Show Wi‑Fi password",
    hotspotPassHideAria: "Hide Wi‑Fi password",
    hotspotHint:
      "SSID and password are case-sensitive — type each character exactly. For /hotspot_on with no extra text, the module uses these values (or defaults Hotspot / 12345678 when left blank).",
    anydeskAutoMediaLabel:
      "Auto-grant AnyDesk media permission (PROJECT_MEDIA) — off by default; check to enable.",
    submit: "Download TelegramControl.zip",
    submitting: "Building ZIP…",
    hint:
      "After install and reboot: only the Chat ID you entered can control the bot.",
    testedDevicesNote:
      "Tested and working on Samsung Galaxy Z Flip4 and Samsung Galaxy Z Fold4. Some devices may be incompatible.",
    errNetwork: "Download failed — check your connection and retry.",
    errContactHint: "If the problem persists or you need support:",
    errContactLink: "contact via Facebook",
    themeDark: "Dark",
    themeLight: "Light",
    langVi: "Tiếng Việt",
    langEn: "English",
    donateTitle: "Donate",
    donateRecipient: "Võ Hoàng Hải Nghĩa",
    donateBankName: "MB Bank",
    contactFacebook: "Contact · Report issues (Facebook)",
    donatePaypal: "Donate · PayPal",
  },
} as const;

export type Strings = (typeof STR)[Lang];

export function pick(lang: Lang): Strings {
  return STR[lang];
}
