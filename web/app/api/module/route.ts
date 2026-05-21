import fs from "fs";
import path from "path";
import JSZip from "jszip";
import { NextResponse } from "next/server";

export const runtime = "nodejs";

const LANG_RE = /^(vi|en)$/;
const TOKEN_RE = /^[0-9]+:[A-Za-z0-9_-]+$/;
const CHAT_RE = /^-?[0-9]+$/;

function shSingleQuoted(value: string): string {
  return `'${value.replace(/'/g, "'\\''")}'`;
}

function utf8ByteLength(value: string): number {
  return Buffer.byteLength(value, "utf8");
}

function hasBadControlChars(value: string): boolean {
  // C0 controls and DEL (incl. tab/newline; newlines are rejected above too)
  return /[\0-\x1F\x7F]/.test(value);
}

/** Stamp module.prop per ZIP so Magisk shows a unique build (version + versionCode). */
function stampModulePropContent(raw: string): string {
  const buildCode = Math.floor(Date.now() / 1000);
  const buildDate = new Date().toISOString().slice(0, 10);
  const lines = raw.split(/\r?\n/);
  let baseVersion = "4.21 Final";
  const out = lines.map((line) => {
    if (line.startsWith("versionCode=")) {
      return `versionCode=${buildCode}`;
    }
    if (line.startsWith("version=")) {
      const v = line.slice("version=".length).trim();
      baseVersion = v.replace(/\s*\([^)]*\)\s*$/, "").trim() || baseVersion;
      return `version=${baseVersion} (${buildDate})`;
    }
    return line;
  });
  if (!out.some((l) => l.startsWith("versionCode="))) {
    out.push(`versionCode=${buildCode}`);
  }
  if (!out.some((l) => l.startsWith("version="))) {
    out.push(`version=${baseVersion} (${buildDate})`);
  }
  return out.join("\n").replace(/\n*$/, "\n");
}

function jsonBilingual(status: number, vi: string, en: string) {
  return NextResponse.json({ errorVi: vi, errorEn: en }, { status });
}

export async function POST(req: Request) {
  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return jsonBilingual(400, "JSON không hợp lệ.", "Invalid JSON body.");
  }

  const lang =
    typeof body === "object" && body !== null && "lang" in body
      ? String((body as { lang?: unknown }).lang ?? "").trim()
      : "";

  const anydeskAutoMedia =
    typeof body === "object" && body !== null && "anydeskAutoMedia" in body
      ? Boolean((body as { anydeskAutoMedia?: unknown }).anydeskAutoMedia)
      : false;

  const token =
    typeof body === "object" && body !== null && "token" in body
      ? String((body as { token?: unknown }).token ?? "").trim()
      : "";
  const chatId =
    typeof body === "object" && body !== null && "chatId" in body
      ? String((body as { chatId?: unknown }).chatId ?? "").trim()
      : "";

  const hotspotSsid =
    typeof body === "object" && body !== null && "hotspotSsid" in body
      ? String((body as { hotspotSsid?: unknown }).hotspotSsid ?? "").trim()
      : "";
  const hotspotPass =
    typeof body === "object" && body !== null && "hotspotPass" in body
      ? String((body as { hotspotPass?: unknown }).hotspotPass ?? "")
      : "";

  if (!TOKEN_RE.test(token)) {
    return jsonBilingual(
      400,
      "Bot token không đúng định dạng.",
      "Bot token format looks invalid.",
    );
  }

  if (!CHAT_RE.test(chatId)) {
    return jsonBilingual(
      400,
      "Chat ID không đúng định dạng.",
      "Chat ID format looks invalid.",
    );
  }

  if (hotspotSsid.includes("\n") || hotspotSsid.includes("\r")) {
    return jsonBilingual(
      400,
      "Tên Wi‑Fi không được chứa xuống dòng.",
      "SSID must not contain line breaks.",
    );
  }
  if (hotspotPass.includes("\n") || hotspotPass.includes("\r")) {
    return jsonBilingual(
      400,
      "Mật khẩu không được chứa xuống dòng.",
      "Password must not contain line breaks.",
    );
  }
  if (hasBadControlChars(hotspotSsid) || hasBadControlChars(hotspotPass)) {
    return jsonBilingual(
      400,
      "SSID hoặc mật khẩu có ký tự không hợp lệ.",
      "SSID or password contains invalid characters.",
    );
  }
  if (utf8ByteLength(hotspotSsid) > 32) {
    return jsonBilingual(
      400,
      "Tên Wi‑Fi quá dài (tối đa 32 byte UTF‑8).",
      "SSID is too long (max 32 UTF‑8 bytes).",
    );
  }
  if (utf8ByteLength(hotspotPass) > 63) {
    return jsonBilingual(
      400,
      "Mật khẩu quá dài (tối đa 63 byte UTF‑8, WPA2).",
      "Password is too long (max 63 UTF‑8 bytes for WPA2).",
    );
  }

  if (lang !== "" && !LANG_RE.test(lang)) {
    return jsonBilingual(
      400,
      "Ngôn ngữ không hợp lệ (chỉ hỗ trợ vi/en).",
      "Invalid language (supported: vi/en).",
    );
  }

  const rootVi = path.join(process.cwd(), "module-files-vi");
  const rootEn = path.join(process.cwd(), "module-files-en");

  if (!fs.existsSync(rootVi)) {
    return jsonBilingual(
      500,
      "Thiếu web/module-files-vi — chạy npm run build trong thư mục web (prebuild chạy sync-module).",
      "Missing web/module-files-vi — run npm run build in web/ (prebuild runs sync-module).",
    );
  }

  let root = rootVi;
  if (LANG_RE.test(lang) && lang === "en") {
    if (!fs.existsSync(rootEn)) {
      return jsonBilingual(
        500,
        "Thiếu web/module-files-en — chạy npm run build trong thư mục web (prebuild chạy sync-module).",
        "Missing web/module-files-en — run npm run build in web/ (prebuild runs sync-module).",
      );
    }
    root = rootEn;
  }

  const needed = [
    "module.prop",
    "service.sh",
    "customize.sh",
    path.join("lib", "common.sh"),
  ];

  for (const rel of needed) {
    if (!fs.existsSync(path.join(root, rel))) {
      return jsonBilingual(
        500,
        "Gói module trong thư mục không đủ — chạy npm run build trong web/ (đồng bộ sync-module).",
        "Incomplete module folder — run npm run build in web/ (sync-module prebuild).",
      );
    }
  }

  // Files must live at ZIP root — Magisk only recognizes module.prop / META-INF at archive root,
  // not inside an extra wrapping folder (would show "not a Magisk module").
  const zip = new JSZip();

  const walk = (relDir: string) => {
    const absDir = path.join(root, relDir);
    for (const name of fs.readdirSync(absDir)) {
      const rel = path.join(relDir, name);
      const abs = path.join(root, rel);
      const st = fs.statSync(abs);
      if (st.isDirectory()) walk(rel);
      else zip.file(rel.replace(/\\/g, "/"), fs.readFileSync(abs));
    }
  };

  for (const name of fs.readdirSync(root)) {
    const abs = path.join(root, name);
    const st = fs.statSync(abs);
    if (st.isDirectory()) walk(name);
    else if (name === "module.prop") {
      zip.file(
        name,
        stampModulePropContent(fs.readFileSync(abs, "utf8")),
      );
    } else {
      zip.file(name, fs.readFileSync(abs));
    }
  }

  let hotspotBlock = "";
  if (hotspotSsid !== "") {
    hotspotBlock += `HOTSPOT_SSID=${shSingleQuoted(hotspotSsid)}\n`;
  }
  if (hotspotPass !== "") {
    hotspotBlock += `HOTSPOT_PASS=${shSingleQuoted(hotspotPass)}\n`;
  }
  if (hotspotBlock !== "") {
    hotspotBlock =
      `\n# Default hotspot when sending plain /hotspot_on (no SSID/password args)\n` +
      hotspotBlock;
  }

  const configBody =
    `# TelegramControl — sinh tự động (đừng chia sẻ file này)\n` +
    `TELEGRAM_TOKEN=${shSingleQuoted(token)}\n` +
    `TELEGRAM_CHAT_ID=${shSingleQuoted(chatId)}\n` +
    (anydeskAutoMedia ? `ANYDESK_AUTO_MEDIA=1\n` : "") +
    hotspotBlock;

  zip.file("config.sh", configBody);

  const buf = await zip.generateAsync({
    type: "nodebuffer",
    compression: "DEFLATE",
    compressionOptions: { level: 9 },
  });

  return new NextResponse(new Uint8Array(buf), {
    status: 200,
    headers: {
      "Content-Type": "application/zip",
      "Content-Disposition": 'attachment; filename="TelegramControl.zip"',
      "Cache-Control": "no-store",
    },
  });
}
