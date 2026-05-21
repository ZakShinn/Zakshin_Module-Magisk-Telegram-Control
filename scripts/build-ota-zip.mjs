#!/usr/bin/env node
/**
 * Gói ZIP OTA cho Magisk (không có config.sh — cập nhật giữ cấu hình cũ).
 * Chạy sau: node web/scripts/sync-module.mjs
 */
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";
import JSZip from "jszip";
import {
  applyOtaToModulePropContent,
  readChannel,
} from "./ota-lib.mjs";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, "..");
const srcRoot = path.join(repoRoot, "web", "module-files-vi");
const distDir = path.join(repoRoot, "dist");
const outZip = path.join(distDir, "TelegramControl-ota.zip");

function walkZip(zip, absDir, relDir = "") {
  for (const name of fs.readdirSync(absDir)) {
    const abs = path.join(absDir, name);
    const rel = relDir ? path.join(relDir, name) : name;
    const st = fs.statSync(abs);
    if (st.isDirectory()) walkZip(zip, abs, rel);
    else zip.file(rel.replace(/\\/g, "/"), fs.readFileSync(abs));
  }
}

if (!fs.existsSync(srcRoot)) {
  console.error("build-ota-zip: run node web/scripts/sync-module.mjs first");
  process.exit(1);
}

const channel = readChannel(repoRoot);
const ota = channel.stable;
if (!ota?.otaEnabled || channel.activeChannel !== "stable") {
  console.error(
    "build-ota-zip: activeChannel must be stable with otaEnabled=true (beta builds must not publish OTA zip)",
  );
  process.exit(1);
}

const zip = new JSZip();
const propRaw = fs.readFileSync(path.join(srcRoot, "module.prop"), "utf8");
zip.file("module.prop", applyOtaToModulePropContent(propRaw, channel));

for (const name of fs.readdirSync(srcRoot)) {
  if (name === "module.prop" || name === "config.sh") continue;
  const abs = path.join(srcRoot, name);
  const st = fs.statSync(abs);
  if (st.isDirectory()) walkZip(zip, abs, name);
  else zip.file(name, fs.readFileSync(abs));
}

fs.mkdirSync(distDir, { recursive: true });
const buf = await zip.generateAsync({
  type: "nodebuffer",
  compression: "DEFLATE",
  compressionOptions: { level: 9 },
});
fs.writeFileSync(outZip, buf);

console.log(`build-ota-zip: ${outZip} (no config.sh — Magisk update keeps user config)`);
