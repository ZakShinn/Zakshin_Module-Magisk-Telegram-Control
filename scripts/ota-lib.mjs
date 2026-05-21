import fs from "fs";
import path from "path";

export function readChannel(repoRoot) {
  const p = path.join(repoRoot, "ota", "channel.json");
  if (!fs.existsSync(p)) {
    throw new Error(`ota-lib: missing ${p}`);
  }
  return JSON.parse(fs.readFileSync(p, "utf8"));
}

export function parseModulePropRaw(raw) {
  const meta = {
    id: "",
    version: "",
    versionCode: 0,
    updateJson: "",
    lines: [],
  };
  for (const line of raw.split(/\r?\n/)) {
    if (line.startsWith("id=")) meta.id = line.slice(3).trim();
    else if (line.startsWith("version=")) meta.version = line.slice(8).trim();
    else if (line.startsWith("versionCode=")) {
      meta.versionCode = parseInt(line.slice(12).trim(), 10) || 0;
    } else if (line.startsWith("updateJson=")) meta.updateJson = line.slice(11).trim();
    meta.lines.push(line);
  }
  return meta;
}

export function parseModulePropFile(filePath) {
  return parseModulePropRaw(fs.readFileSync(filePath, "utf8"));
}

export function rawUpdateJsonUrl(channel, kind) {
  const repo = channel.repository;
  const branch = channel.branch || "main";
  const file = channel[kind]?.updateJsonFile || `ota/update-${kind}.json`;
  return `https://raw.githubusercontent.com/${repo}/${branch}/${file}`;
}

export function activeOtaConfig(channel) {
  const name = channel.activeChannel === "beta" ? "beta" : "stable";
  const cfg = channel[name] || channel.stable;
  const enabled = Boolean(cfg?.otaEnabled) && name === "stable";
  return { channelName: name, cfg, enabled, updateJsonUrl: rawUpdateJsonUrl(channel, name) };
}

/** Inject or strip updateJson for Magisk in-app update. */
export function applyOtaToModulePropContent(raw, channel) {
  const { enabled, updateJsonUrl } = activeOtaConfig(channel);
  const out = [];
  let hadUpdate = false;
  for (const line of raw.split(/\r?\n/)) {
    if (line.startsWith("updateJson=")) {
      hadUpdate = true;
      if (enabled) out.push(`updateJson=${updateJsonUrl}`);
      continue;
    }
    out.push(line);
  }
  if (enabled && !hadUpdate) out.push(`updateJson=${updateJsonUrl}`);
  return out.join("\n").replace(/\n*$/, "\n");
}

export function stampVersionDate(raw, buildDate) {
  const out = [];
  for (const line of raw.split(/\r?\n/)) {
    if (line.startsWith("version=")) {
      const v = line.slice(8).trim().replace(/\s*\([^)]*\)\s*$/, "").trim();
      out.push(`version=${v} (${buildDate})`);
      continue;
    }
    out.push(line);
  }
  return out.join("\n").replace(/\n*$/, "\n");
}

export function writeUpdateStableJson(repoRoot, meta, tag) {
  const channel = readChannel(repoRoot);
  const asset = channel.stable?.releaseAssetName || "TelegramControl-ota.zip";
  const ver = meta.version.replace(/\s*\([^)]*\)\s*$/, "").trim();
  const zipUrl = `https://github.com/${channel.repository}/releases/download/${tag}/${asset}`;
  const changelog = `https://raw.githubusercontent.com/${channel.repository}/${channel.branch || "main"}/ota/changelog.md`;
  const body = {
    version: ver,
    versionCode: meta.versionCode,
    zipUrl,
    changelog,
  };
  const outPath = path.join(repoRoot, "ota", "update-stable.json");
  fs.writeFileSync(outPath, `${JSON.stringify(body, null, 2)}\n`, "utf8");
  return body;
}
