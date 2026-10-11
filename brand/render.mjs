/**
 * Renders brand/svg/*.svg to PNGs with Chromium (exact SVG rendering, real
 * transparency).
 *
 *   PLAYWRIGHT_DIR=<dir with node_modules/playwright> node brand/render.mjs
 *
 * Output: brand/png/<name>-<size>.png for each size listed below.
 */
import { createRequire } from "node:module";
import { mkdirSync, readFileSync } from "node:fs";
import { join } from "node:path";

const require = createRequire(join(process.env.PLAYWRIGHT_DIR, "package.json"));
const { chromium } = require("playwright");

const here = new URL(".", import.meta.url).pathname.replace(/^\/(\w:)/, "$1");
const out = join(here, "png");
mkdirSync(out, { recursive: true });

const jobs = {
  "icon-square": [1024],
  "icon-rounded": [1024, 512, 192, 180, 64, 32],
  "adaptive-background": [1024],
  "adaptive-foreground": [1024],
  "adaptive-monochrome": [1024],
  "twiga-head": [384, 64],
};

const browser = await chromium.launch();
const page = await browser.newPage();
for (const [name, sizes] of Object.entries(jobs)) {
  const svg = readFileSync(join(here, "svg", `${name}.svg`), "utf8");
  for (const size of sizes) {
    await page.setViewportSize({ width: size, height: size });
    await page.setContent(
      `<html><body style="margin:0;background:transparent">` +
        svg.replace('width="1024" height="1024"', `width="${size}" height="${size}"`) +
        `</body></html>`,
    );
    await page.screenshot({ path: join(out, `${name}-${size}.png`), omitBackground: true });
  }
}
await browser.close();
console.log("rendered to brand/png/");
