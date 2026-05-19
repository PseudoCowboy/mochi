const { Jimp } = require('jimp');

async function createIcon(filename, bgColorHex, fgColorHex, eyeColorHex) {
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
    
    await img.write(filename);
}

async function run() {
    await createIcon('Mochi/Assets.xcassets/AppIcon.appiconset/icon-1024.png', 0xFAD961FF, 0xFFFFFFFF, 0xFAD961FF);
    await createIcon('Mochi/Assets.xcassets/AppIcon.appiconset/icon-dark-1024.png', 0x191919FF, 0xFFFFFFFF, 0x191919FF);
    await createIcon('Mochi/Assets.xcassets/AppIcon.appiconset/icon-tinted-1024.png', 0x000000FF, 0xFAD961FF, 0x000000FF);
}

run().catch(console.error);
