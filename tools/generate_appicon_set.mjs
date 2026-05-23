#!/usr/bin/env node
// Generate full iOS + watchOS AppIcon raster sets and rewrite their
// Contents.json manifests. Idempotent: re-running produces no diff.
//
// Reuses the existing 1024x1024 default-light source PNGs produced by
// generate_icons.js (Mochi/Assets.xcassets/AppIcon.appiconset/icon-1024.png
// and Mochi Watch App/Assets.xcassets/AppIcon.appiconset/icon-1024.png) as
// the downscale source for all sized variants. Preserves the existing
// iOS dark/tinted 1024 variants (icon-dark-1024.png, icon-tinted-1024.png)
// unchanged.

import { promises as fs } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import sharp from "sharp";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const REPO_ROOT = path.resolve(__dirname, "..");

const IOS_SET = path.join(
    REPO_ROOT,
    "Mochi",
    "Assets.xcassets",
    "AppIcon.appiconset"
);
const WATCH_SET = path.join(
    REPO_ROOT,
    "Mochi Watch App",
    "Assets.xcassets",
    "AppIcon.appiconset"
);

// ---------- iOS spec ----------
// iPhone sized entries (20/29/40/60 at applicable scales) plus the
// two iPad-only sizes (76, 83.5) the work-item explicitly requires.
// Existing universal 1024 entries (default, dark, tinted) are preserved
// as marketing/appearance slots; dark/tinted stay 1024-only per spec.
const IOS_SIZED = [
    { idiom: "iphone", size: 20, scale: 2 },
    { idiom: "iphone", size: 20, scale: 3 },
    { idiom: "iphone", size: 29, scale: 2 },
    { idiom: "iphone", size: 29, scale: 3 },
    { idiom: "iphone", size: 40, scale: 2 },
    { idiom: "iphone", size: 40, scale: 3 },
    { idiom: "iphone", size: 60, scale: 2 },
    { idiom: "iphone", size: 60, scale: 3 },
    { idiom: "ipad",   size: 76,   scale: 2 },
    { idiom: "ipad",   size: 83.5, scale: 2 },
];

// ---------- watchOS spec ----------
// Apple AppIcon for watchOS — full role/subtype matrix.
const WATCH_SIZED = [
    { size: 24,    scale: 2, role: "notificationCenter", subtype: "38mm" },
    { size: 27.5,  scale: 2, role: "notificationCenter", subtype: "42mm" },
    { size: 29,    scale: 2, role: "companionSettings" },
    { size: 29,    scale: 3, role: "companionSettings" },
    { size: 33,    scale: 2, role: "notificationCenter", subtype: "45mm" },
    { size: 40,    scale: 2, role: "appLauncher",        subtype: "38mm" },
    { size: 44,    scale: 2, role: "appLauncher",        subtype: "40mm" },
    { size: 50,    scale: 2, role: "appLauncher",        subtype: "44mm" },
    { size: 86,    scale: 2, role: "quickLook",          subtype: "38mm" },
    { size: 98,    scale: 2, role: "quickLook",          subtype: "42mm" },
    { size: 108,   scale: 2, role: "quickLook",          subtype: "44mm" },
];

// Format a size value as Apple's spec writes it: integers without a
// trailing ".0" but preserving fractional values (83.5, 27.5).
function fmt(n) {
    return Number.isInteger(n) ? String(n) : String(n);
}

// Pixel dimension after applying scale; rounded to the nearest pixel
// (only 83.5@2x = 167, 27.5@2x = 55, 33@2x = 66, all exact).
function pixelDim(size, scale) {
    return Math.round(size * scale);
}

// Filename convention: icon-<size>[@<scale>x][-<idiom>].png
// iPad entries are suffixed with "-ipad" to disambiguate from iPhone
// entries that share size+scale (e.g. 40@2x exists on both).
function iosFilename(entry) {
    const sizeStr = fmt(entry.size);
    const scaleStr = `@${entry.scale}x`;
    const idiomTag = entry.idiom === "ipad" ? "-ipad" : "";
    return `icon-${sizeStr}${scaleStr}${idiomTag}.png`;
}

function watchFilename(entry) {
    const sizeStr = fmt(entry.size);
    const scaleStr = `@${entry.scale}x`;
    // Disambiguate same-size@scale entries by role/subtype.
    const tags = [entry.role];
    if (entry.subtype) tags.push(entry.subtype);
    return `icon-${sizeStr}${scaleStr}-${tags.join("-")}.png`;
}

async function ensureSizedPng(srcBuffer, outPath, pixels) {
    // Idempotent: only rewrite if the file is missing or its byte content
    // would actually change. sharp output is deterministic for fixed
    // inputs, so byte compare is reliable.
    const rendered = await sharp(srcBuffer)
        .resize(pixels, pixels, { fit: "cover", kernel: "lanczos3" })
        .png({ compressionLevel: 9, adaptiveFiltering: false, palette: false })
        .toBuffer();

    let existing = null;
    try {
        existing = await fs.readFile(outPath);
    } catch (e) {
        if (e.code !== "ENOENT") throw e;
    }
    if (existing && existing.equals(rendered)) return false;
    await fs.writeFile(outPath, rendered);
    return true;
}

async function writeJsonIfChanged(outPath, obj) {
    const serialized = JSON.stringify(obj, null, 2) + "\n";
    let existing = null;
    try {
        existing = await fs.readFile(outPath, "utf8");
    } catch (e) {
        if (e.code !== "ENOENT") throw e;
    }
    if (existing === serialized) return false;
    await fs.writeFile(outPath, serialized, "utf8");
    return true;
}

// Remove any icon-*.png in the set directory that the new manifest no
// longer references. Keeps the marketing/appearance 1024 PNGs in the
// preserve list. Skips Contents.json and any non-PNG files. Returns the
// list of removed filenames so the run summary can report on it.
async function pruneOrphans(setDir, keepFilenames) {
    const keep = new Set(keepFilenames);
    const entries = await fs.readdir(setDir);
    const removed = [];
    for (const name of entries) {
        if (!name.toLowerCase().endsWith(".png")) continue;
        if (keep.has(name)) continue;
        await fs.unlink(path.join(setDir, name));
        removed.push(name);
    }
    return removed;
}

async function generateIos() {
    const srcPath = path.join(IOS_SET, "icon-1024.png");
    const srcBuffer = await fs.readFile(srcPath);

    const imagesGenerated = [];
    for (const entry of IOS_SIZED) {
        const filename = iosFilename(entry);
        const px = pixelDim(entry.size, entry.scale);
        const outPath = path.join(IOS_SET, filename);
        const changed = await ensureSizedPng(srcBuffer, outPath, px);
        imagesGenerated.push({ entry, filename, px, changed });
    }

    // Build Contents.json. Order: sized entries (iphone then ipad), then
    // the preserved universal 1024 entries (default, dark, tinted).
    const images = [];
    for (const { entry, filename } of imagesGenerated) {
        images.push({
            filename,
            idiom: entry.idiom,
            scale: `${entry.scale}x`,
            size: `${fmt(entry.size)}x${fmt(entry.size)}`,
        });
    }
    // Preserve dark/tinted + default-light universal 1024 entries.
    images.push({
        filename: "icon-1024.png",
        idiom: "universal",
        platform: "ios",
        size: "1024x1024",
    });
    images.push({
        appearances: [{ appearance: "luminosity", value: "dark" }],
        filename: "icon-dark-1024.png",
        idiom: "universal",
        platform: "ios",
        size: "1024x1024",
    });
    images.push({
        appearances: [{ appearance: "luminosity", value: "tinted" }],
        filename: "icon-tinted-1024.png",
        idiom: "universal",
        platform: "ios",
        size: "1024x1024",
    });

    const manifest = {
        images,
        info: { author: "xcode", version: 1 },
    };
    const manifestPath = path.join(IOS_SET, "Contents.json");
    const manifestChanged = await writeJsonIfChanged(manifestPath, manifest);

    const keep = images.map((i) => i.filename);
    const removed = await pruneOrphans(IOS_SET, keep);

    const sizedChanged = imagesGenerated.filter((g) => g.changed).length;
    console.log(
        `iOS: ${imagesGenerated.length} sized PNGs (${sizedChanged} written, ` +
        `${removed.length} pruned), ` +
        `manifest ${manifestChanged ? "rewritten" : "unchanged"}`
    );
}

async function generateWatch() {
    const srcPath = path.join(WATCH_SET, "icon-1024.png");
    const srcBuffer = await fs.readFile(srcPath);

    const imagesGenerated = [];
    for (const entry of WATCH_SIZED) {
        const filename = watchFilename(entry);
        const px = pixelDim(entry.size, entry.scale);
        const outPath = path.join(WATCH_SET, filename);
        const changed = await ensureSizedPng(srcBuffer, outPath, px);
        imagesGenerated.push({ entry, filename, px, changed });
    }

    const images = [];
    for (const { entry, filename } of imagesGenerated) {
        const obj = {
            filename,
            idiom: "watch",
            role: entry.role,
            scale: `${entry.scale}x`,
            size: `${fmt(entry.size)}x${fmt(entry.size)}`,
        };
        if (entry.subtype) obj.subtype = entry.subtype;
        images.push(obj);
    }
    // Marketing 1024 — preserved.
    images.push({
        filename: "icon-1024.png",
        idiom: "watch-marketing",
        scale: "1x",
        size: "1024x1024",
    });

    const manifest = {
        images,
        info: { author: "xcode", version: 1 },
    };
    const manifestPath = path.join(WATCH_SET, "Contents.json");
    const manifestChanged = await writeJsonIfChanged(manifestPath, manifest);

    const keep = images.map((i) => i.filename);
    const removed = await pruneOrphans(WATCH_SET, keep);

    const sizedChanged = imagesGenerated.filter((g) => g.changed).length;
    console.log(
        `watchOS: ${imagesGenerated.length} sized PNGs (${sizedChanged} written, ` +
        `${removed.length} pruned), ` +
        `manifest ${manifestChanged ? "rewritten" : "unchanged"}`
    );
}

async function main() {
    await generateIos();
    await generateWatch();
}

main().catch((err) => {
    console.error(err);
    process.exit(1);
});
