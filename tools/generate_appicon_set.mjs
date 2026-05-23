import fs from 'fs/promises';
import path from 'path';
import { Jimp } from 'jimp';
import sharp from 'sharp';

async function createIconBuffer(bgColorHex, fgColorHex, eyeColorHex) {
    const img = new Jimp({ width: 1024, height: 1024, color: bgColorHex });

    for(let y=0; y<1024; y++){
        for(let x=0; x<1024; x++){
            const dx = x - 512;
            const dy = y - 512;
            if (dx*dx + dy*dy <= 300*300) {
                img.setPixelColor(fgColorHex, x, y);
            }
            
            // Eyes
            const dxE1 = x - 452;
            const dyE1 = y - 472;
            if (dxE1*dxE1 + dyE1*dyE1 <= 40*40) {
                img.setPixelColor(eyeColorHex, x, y);
            }
            
            const dxE2 = x - 572;
            const dyE2 = y - 472;
            if (dxE2*dxE2 + dyE2*dyE2 <= 40*40) {
                img.setPixelColor(eyeColorHex, x, y);
            }
        }
    }

    for(let y=0; y<1024; y++){
        for(let x=0; x<1024; x++){
            if (y > 550) {
                const dxS = x - 512;
                const dyS = y - 550;
                const dist = Math.sqrt(dxS*dxS + dyS*dyS);
                if (dist >= 80 && dist <= 120 && dxS >= -98 && dxS <= 98) {
                    img.setPixelColor(eyeColorHex, x, y);
                }
                
                const dxEnd1 = x - 414;
                const dyEnd1 = y - 570;
                if (dxEnd1*dxEnd1 + dyEnd1*dyEnd1 <= 20*20) {
                    img.setPixelColor(eyeColorHex, x, y);
                }
                const dxEnd2 = x - 610;
                const dyEnd2 = y - 570;
                if (dxEnd2*dxEnd2 + dyEnd2*dyEnd2 <= 20*20) {
                    img.setPixelColor(eyeColorHex, x, y);
                }
            }
        }
    }
    
    return await img.getBuffer('image/png');
}

async function writeContentsJson(dir, json) {
    await fs.writeFile(path.join(dir, 'Contents.json'), JSON.stringify(json, null, 2));
}

async function run() {
    const iosDir = 'Mochi/Assets.xcassets/AppIcon.appiconset';
    const watchDir = 'Mochi Watch App/Assets.xcassets/AppIcon.appiconset';

    // The color is #FF9F7A for BrandPrimary light. Add FF for alpha
    const lightBg = 0xFF9F7AFF;
    const darkBg = 0x191919FF;
    const tintedBg = 0x000000FF;

    const baseBufferLight = await createIconBuffer(lightBg, 0xFFFFFFFF, lightBg);
    const baseBufferDark = await createIconBuffer(darkBg, 0xFFFFFFFF, darkBg);
    const baseBufferTinted = await createIconBuffer(tintedBg, 0xFF9F7AFF, tintedBg);
    
    await fs.mkdir(iosDir, { recursive: true });
    await fs.mkdir(watchDir, { recursive: true });

    // Ensure 1024 icons exist for iOS
    await sharp(baseBufferLight).png().toFile(path.join(iosDir, 'icon-1024.png'));
    await sharp(baseBufferDark).png().toFile(path.join(iosDir, 'icon-dark-1024.png'));
    await sharp(baseBufferTinted).png().toFile(path.join(iosDir, 'icon-tinted-1024.png'));

    // iOS config matching the one we read
    const iosImages = [
        { size: 20, idiom: "iphone", scales: [2, 3] },
        { size: 29, idiom: "iphone", scales: [2, 3] },
        { size: 40, idiom: "iphone", scales: [2, 3] },
        { size: 60, idiom: "iphone", scales: [2, 3] },
        { size: 76, idiom: "ipad", scales: [2] },
        { size: 83.5, idiom: "ipad", scales: [2] }
    ];

    const iosContents = { images: [], info: { author: "xcode", version: 1 } };
    
    for (const spec of iosImages) {
        for (const scale of spec.scales) {
            const dim = spec.size * scale;
            const suffix = spec.idiom === 'ipad' ? '-ipad' : '';
            const filename = `icon-${spec.size}@${scale}x${suffix}.png`;
            await sharp(baseBufferLight).resize(dim, dim).png().toFile(path.join(iosDir, filename));
            iosContents.images.push({
                size: `${spec.size}x${spec.size}`,
                idiom: spec.idiom,
                filename: filename,
                scale: `${scale}x`
            });
        }
    }

    // Add universal 1024 and dark/tinted variants
    iosContents.images.push({ size: "1024x1024", idiom: "universal", platform: "ios", filename: "icon-1024.png" });
    iosContents.images.push({ size: "1024x1024", idiom: "universal", platform: "ios", filename: "icon-dark-1024.png", appearances: [{ appearance: "luminosity", value: "dark" }] });
    iosContents.images.push({ size: "1024x1024", idiom: "universal", platform: "ios", filename: "icon-tinted-1024.png", appearances: [{ appearance: "luminosity", value: "tinted" }] });

    await writeContentsJson(iosDir, iosContents);

    // Watch config matching the one we read
    const watchContents = { images: [], info: { author: "xcode", version: 1 } };
    const watchImages = [
        { size: 24, role: "notificationCenter", subtype: "38mm", scale: 2 },
        { size: 27.5, role: "notificationCenter", subtype: "42mm", scale: 2 },
        { size: 29, role: "companionSettings", scale: 2 },
        { size: 29, role: "companionSettings", scale: 3 },
        { size: 33, role: "notificationCenter", subtype: "45mm", scale: 2 },
        { size: 40, role: "appLauncher", subtype: "38mm", scale: 2 },
        { size: 44, role: "appLauncher", subtype: "40mm", scale: 2 },
        { size: 50, role: "appLauncher", subtype: "44mm", scale: 2 },
        { size: 86, role: "quickLook", subtype: "38mm", scale: 2 },
        { size: 98, role: "quickLook", subtype: "42mm", scale: 2 },
        { size: 108, role: "quickLook", subtype: "44mm", scale: 2 },
    ];

    for (const spec of watchImages) {
        const dim = spec.size * spec.scale;
        const sub = spec.subtype ? `-${spec.subtype}` : '';
        const filename = `icon-${spec.size}@${spec.scale}x-${spec.role}${sub}.png`;
        await sharp(baseBufferLight).resize(dim, dim).png().toFile(path.join(watchDir, filename));
        
        const entry = {
            size: `${spec.size}x${spec.size}`,
            idiom: "watch",
            role: spec.role,
            filename: filename,
            scale: `${spec.scale}x`
        };
        if (spec.subtype) entry.subtype = spec.subtype;
        watchContents.images.push(entry);
    }
    
    // Add marketing icon
    await sharp(baseBufferLight).png().toFile(path.join(watchDir, 'icon-1024.png'));
    watchContents.images.push({ size: "1024x1024", idiom: "watch-marketing", filename: "icon-1024.png", scale: "1x" });

    await writeContentsJson(watchDir, watchContents);
}

run().catch(console.error);