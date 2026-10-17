const fs = require('fs');
const path = require('path');
const sharp = require('sharp');

const iconsDir = path.join(__dirname, '..', 'public', 'icons');
if (!fs.existsSync(iconsDir)) {
  fs.mkdirSync(iconsDir, { recursive: true });
}

// Generate an SVG for standard icon
function createSvg(size, isMaskable = false) {
  const padding = isMaskable ? size * 0.15 : size * 0.08;
  const contentSize = size - padding * 2;
  const radius = isMaskable ? 0 : size * 0.22;

  return `
  <svg width="${size}" height="${size}" viewBox="0 0 ${size} ${size}" xmlns="http://www.w3.org/2000/svg">
    <defs>
      <linearGradient id="bgGrad" x1="0%" y1="0%" x2="100%" y2="100%">
        <stop offset="0%" stop-color="#0F172A" />
        <stop offset="100%" stop-color="#020617" />
      </linearGradient>
      <linearGradient id="emeraldGrad" x1="0%" y1="0%" x2="100%" y2="100%">
        <stop offset="0%" stop-color="#34D399" />
        <stop offset="50%" stop-color="#10B981" />
        <stop offset="100%" stop-color="#059669" />
      </linearGradient>
      <linearGradient id="glowGrad" x1="0%" y1="0%" x2="0%" y2="100%">
        <stop offset="0%" stop-color="#10B981" stop-opacity="0.35" />
        <stop offset="100%" stop-color="#10B981" stop-opacity="0" />
      </linearGradient>
      <filter id="shadow" x="-10%" y="-10%" width="120%" height="120%">
        <feDropShadow dx="0" dy="4" stdDeviation="6" flood-color="#000000" flood-opacity="0.5" />
      </filter>
    </defs>

    <!-- Background -->
    <rect width="${size}" height="${size}" rx="${radius}" fill="url(#bgGrad)" />

    <!-- Subtle inner border -->
    <rect x="1" y="1" width="${size - 2}" height="${size - 2}" rx="${Math.max(0, radius - 1)}" fill="none" stroke="#334155" stroke-width="2" stroke-opacity="0.4" />

    <!-- Decorative ambient glow -->
    <circle cx="${size * 0.5}" cy="${size * 0.35}" r="${size * 0.35}" fill="url(#glowGrad)" />

    <!-- Icon Content: Bold Geometric "BB" Monogram -->
    <g transform="translate(${padding}, ${padding})">
      <!-- First 'B' (Outer Bridge Arc) -->
      <path d="
        M ${contentSize * 0.18} ${contentSize * 0.18}
        L ${contentSize * 0.48} ${contentSize * 0.18}
        C ${contentSize * 0.64} ${contentSize * 0.18}, ${contentSize * 0.72} ${contentSize * 0.28}, ${contentSize * 0.72} ${contentSize * 0.42}
        C ${contentSize * 0.72} ${contentSize * 0.52}, ${contentSize * 0.65} ${contentSize * 0.56}, ${contentSize * 0.56} ${contentSize * 0.58}
        C ${contentSize * 0.68} ${contentSize * 0.62}, ${contentSize * 0.76} ${contentSize * 0.72}, ${contentSize * 0.76} ${contentSize * 0.82}
        L ${contentSize * 0.18} ${contentSize * 0.82}
        Z
      " fill="url(#emeraldGrad)" filter="url(#shadow)" />

      <!-- Inner cutouts of 'B' -->
      <!-- Top Loop -->
      <path d="
        M ${contentSize * 0.34} ${contentSize * 0.30}
        L ${contentSize * 0.46} ${contentSize * 0.30}
        C ${contentSize * 0.54} ${contentSize * 0.30}, ${contentSize * 0.58} ${contentSize * 0.34}, ${contentSize * 0.58} ${contentSize * 0.42}
        C ${contentSize * 0.58} ${contentSize * 0.48}, ${contentSize * 0.54} ${contentSize * 0.50}, ${contentSize * 0.46} ${contentSize * 0.50}
        L ${contentSize * 0.34} ${contentSize * 0.50}
        Z
      " fill="#0F172A" />

      <!-- Bottom Loop -->
      <path d="
        M ${contentSize * 0.34} ${contentSize * 0.58}
        L ${contentSize * 0.48} ${contentSize * 0.58}
        C ${contentSize * 0.58} ${contentSize * 0.58}, ${contentSize * 0.62} ${contentSize * 0.64}, ${contentSize * 0.62} ${contentSize * 0.70}
        C ${contentSize * 0.62} ${contentSize * 0.76}, ${contentSize * 0.58} ${contentSize * 0.78}, ${contentSize * 0.48} ${contentSize * 0.78}
        L ${contentSize * 0.34} ${contentSize * 0.78}
        Z
      " fill="#0F172A" />

      <!-- Bridge Horizontal Accent Node -->
      <rect x="${contentSize * 0.68}" y="${contentSize * 0.46}" width="${contentSize * 0.22}" height="${contentSize * 0.08}" rx="${contentSize * 0.04}" fill="#34D399" />
      <circle cx="${contentSize * 0.85}" cy="${contentSize * 0.5}" r="${contentSize * 0.08}" fill="#6EE7B7" />
    </g>
  </svg>
  `;
}

async function run() {
  console.log('Generating PWA icons...');
  
  // 192x192
  const svg192 = createSvg(192, false);
  await sharp(Buffer.from(svg192)).png().toFile(path.join(iconsDir, 'icon-192.png'));
  console.log('Created icon-192.png');

  // 512x512
  const svg512 = createSvg(512, false);
  await sharp(Buffer.from(svg512)).png().toFile(path.join(iconsDir, 'icon-512.png'));
  console.log('Created icon-512.png');

  // Maskable 192x192
  const svgMaskable192 = createSvg(192, true);
  await sharp(Buffer.from(svgMaskable192)).png().toFile(path.join(iconsDir, 'icon-maskable-192.png'));
  console.log('Created icon-maskable-192.png');

  // Maskable 512x512
  const svgMaskable512 = createSvg(512, true);
  await sharp(Buffer.from(svgMaskable512)).png().toFile(path.join(iconsDir, 'icon-maskable-512.png'));
  console.log('Created icon-maskable-512.png');

  // Apple Touch Icon (180x180)
  const svgApple = createSvg(180, false);
  await sharp(Buffer.from(svgApple)).png().toFile(path.join(iconsDir, 'apple-touch-icon.png'));
  console.log('Created apple-touch-icon.png');

  // Save SVG logo in public
  fs.writeFileSync(path.join(__dirname, '..', 'public', 'icons', 'icon.svg'), svg512);
  console.log('Created icon.svg');

  console.log('All icons generated successfully!');
}

run().catch(err => {
  console.error('Error generating icons:', err);
  process.exit(1);
});
