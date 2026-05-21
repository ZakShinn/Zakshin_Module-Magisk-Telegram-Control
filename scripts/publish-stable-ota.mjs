#!/usr/bin/env node
/**
 * Cập nhật ota/update-stable.json theo module.prop + tag release.
 * Usage: node scripts/publish-stable-ota.mjs v4.22.0
 */
import path from "path";
import { fileURLToPath } from "url";
import {
  parseModulePropFile,
  readChannel,
  writeUpdateStableJson,
} from "./ota-lib.mjs";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, "..");
const tag = process.argv[2];

if (!tag) {
  console.error("Usage: node scripts/publish-stable-ota.mjs <release-tag>");
  console.error("Example: node scripts/publish-stable-ota.mjs v4.21.0");
  process.exit(1);
}

const channel = readChannel(repoRoot);
if (channel.activeChannel !== "stable" || !channel.stable?.otaEnabled) {
  console.error("publish-stable-ota: set activeChannel=stable and stable.otaEnabled=true");
  process.exit(1);
}

const meta = parseModulePropFile(path.join(repoRoot, "module.prop"));
const body = writeUpdateStableJson(repoRoot, meta, tag);
console.log("publish-stable-ota: wrote ota/update-stable.json");
console.log(JSON.stringify(body, null, 2));
