#!/usr/bin/env node
/**
 * Re-applies the dark-mode bootsplash variants that `react-native-bootsplash`
 * can't generate for us (its --dark-logo / --dark-background flags are gated
 * behind a paid license key).
 *
 * Copy into `scripts/bootsplash-dark.mjs`, edit the CONFIG block, and chain it
 * onto the generate script:
 *
 *   "get-bootsplash": "yarn react-native-bootsplash generate … && yarn bootsplash-dark",
 *   "bootsplash-dark": "node scripts/bootsplash-dark.mjs"
 *
 * It must run as the SECOND half, because the generator overwrites the iOS asset
 * catalogs, the Android drawables and the JS manifest every time — dropping
 * everything below.
 *
 * Idempotent: safe to re-run without regenerating.
 *
 * Requires `sharp` (the same rasteriser the CLI uses, so light and dark PNGs
 * render identically).
 */
import { readFileSync, writeFileSync, mkdirSync, readdirSync, existsSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

import sharp from 'sharp';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');

// ── CONFIG ───────────────────────────────────────────────────────────────────
/** Keep in sync with darkTheme.surface in the app's theme file. */
const DARK_BACKGROUND = '#26231e';
const DARK_LOGO_SVG = join(ROOT, 'bootsplash/logo-dark.svg');

/** Must match --logo-width in the generate script. */
const LOGO_WIDTH = 180;

/** Where the generator wrote the JS assets (--assets-output). */
const JS_ASSETS_DIR = join(ROOT, 'src/assets/bootsplash');

/**
 * The Xcode app directory holding the asset catalogs, i.e. ios/<App>/.
 * Discovered by finding the one that contains Images.xcassets.
 */
const IOS_APP_DIR = (() => {
  const iosDir = join(ROOT, 'ios');
  const match = readdirSync(iosDir).find(name =>
    existsSync(join(iosDir, name, 'Images.xcassets')),
  );
  if (!match) {
    throw new Error('No ios/<App>/Images.xcassets found — set IOS_APP_DIR by hand.');
  }
  return join(iosDir, match);
})();
// ─────────────────────────────────────────────────────────────────────────────

const DARK_APPEARANCE = [{ appearance: 'luminosity', value: 'dark' }];

const rel = p => p.slice(ROOT.length + 1);
const readJson = p => JSON.parse(readFileSync(p, 'utf8'));
const writeJson = (p, v) => writeFileSync(p, `${JSON.stringify(v, null, 2)}\n`);

/** Rasterise the dark SVG to `px` square, preserving transparency. */
async function render(out, px) {
  mkdirSync(dirname(out), { recursive: true });
  await sharp(DARK_LOGO_SVG, { density: 576 })
    .resize(px, px, { fit: 'contain', background: { r: 0, g: 0, b: 0, alpha: 0 } })
    .png()
    .toFile(out);
  console.log(`    ${rel(out)} (${px}x${px})`);
}

function hexToComponents(hex) {
  const h = hex.replace('#', '');
  const c = i => (parseInt(h.slice(i, i + 2), 16) / 255).toFixed(15);
  return { blue: c(4), green: c(2), red: c(0), alpha: '1.000' };
}

/** The generator's hash suffix changes with its arguments, so discover it. */
function findHash() {
  const dir = join(IOS_APP_DIR, 'Images.xcassets');
  const match = readdirSync(dir).find(n => n.startsWith('BootSplashLogo-'));
  if (!match) {
    throw new Error(
      `No BootSplashLogo-*.imageset in ${rel(dir)} — run \`yarn get-bootsplash\` first.`,
    );
  }
  return match.replace('BootSplashLogo-', '').replace('.imageset', '');
}

async function ios(hash) {
  console.log('🍏  iOS launch screen');

  const imageset = join(
    IOS_APP_DIR,
    `Images.xcassets/BootSplashLogo-${hash}.imageset`,
  );
  const scales = [1, 2, 3];

  for (const scale of scales) {
    const suffix = scale === 1 ? '' : `@${scale}x`;
    await render(join(imageset, `logo-${hash}-dark${suffix}.png`), LOGO_WIDTH * scale);
  }

  const contents = readJson(join(imageset, 'Contents.json'));
  contents.images = [
    ...contents.images.filter(i => i.appearances == null),
    ...scales.map(scale => ({
      idiom: 'universal',
      appearances: DARK_APPEARANCE,
      filename: `logo-${hash}-dark${scale === 1 ? '' : `@${scale}x`}.png`,
      scale: `${scale}x`,
    })),
  ];
  writeJson(join(imageset, 'Contents.json'), contents);
  console.log(`    ${rel(join(imageset, 'Contents.json'))}`);

  const colorset = join(
    IOS_APP_DIR,
    `Colors.xcassets/BootSplashBackground-${hash}.colorset/Contents.json`,
  );
  const colors = readJson(colorset);
  colors.colors = [
    ...colors.colors.filter(c => c.appearances == null),
    {
      idiom: 'universal',
      appearances: DARK_APPEARANCE,
      color: {
        'color-space': 'srgb',
        components: hexToComponents(DARK_BACKGROUND),
      },
    },
  ];
  writeJson(colorset, colors);
  console.log(`    ${rel(colorset)}`);
}

async function android() {
  console.log('🤖  Android');

  // Same buckets and sizes the generator uses for drawable-*.
  const buckets = { mdpi: 288, hdpi: 432, xhdpi: 576, xxhdpi: 864, xxxhdpi: 1152 };

  for (const [dpi, px] of Object.entries(buckets)) {
    await render(
      join(ROOT, `android/app/src/main/res/drawable-night-${dpi}/bootsplash_logo.png`),
      px,
    );
  }

  const colors = join(ROOT, 'android/app/src/main/res/values-night/colors.xml');
  mkdirSync(dirname(colors), { recursive: true });
  writeFileSync(
    colors,
    `<resources>
    <!-- Dark counterpart of values/colors.xml — darkTheme.surface in the theme file.
         Generated by scripts/bootsplash-dark.mjs. -->
    <color name="bootsplash_background">${DARK_BACKGROUND}</color>
</resources>
`,
  );
  console.log(`    ${rel(colors)}`);
}

async function js() {
  console.log('📄  JS overlay (AnimatedBootSplash)');

  // Scale suffixes React Native resolves at require() time.
  const scales = [
    ['', 1],
    ['@1,5x', 1.5],
    ['@2x', 2],
    ['@3x', 3],
    ['@4x', 4],
  ];

  for (const [suffix, scale] of scales) {
    await render(
      join(JS_ASSETS_DIR, `logo-dark${suffix}.png`),
      LOGO_WIDTH * scale,
    );
  }

  const manifestPath = join(JS_ASSETS_DIR, 'manifest.json');
  const manifest = readJson(manifestPath);
  // useHideAnimation reads darkBackground itself — the runtime supports dark
  // mode even though the generator won't emit it.
  writeJson(manifestPath, {
    background: manifest.background,
    darkBackground: DARK_BACKGROUND,
    logo: manifest.logo,
  });
  console.log(`    ${rel(manifestPath)}`);
}

const hash = findHash();
await ios(hash);
await android();
await js();
console.log(`\n🌙  Dark bootsplash variants applied (asset hash ${hash}).`);
