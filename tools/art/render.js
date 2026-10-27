// Renders SVG files to transparent PNGs with Chromium (exactly what we preview).
// usage: node render.js <jobs.json>   jobs: [{svg, png, w, h, scale}]
const { chromium } = require('playwright');
const fs = require('fs');
(async () => {
  const jobs = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
  const browser = await chromium.launch();
  const page = await browser.newPage();
  for (const j of jobs) {
    const scale = j.scale || 1;
    await page.setViewportSize({ width: Math.ceil(j.w * scale), height: Math.ceil(j.h * scale) });
    const svg = fs.readFileSync(j.svg, 'utf8');
    const fontCss = j.fonts ? `<style>${j.fonts}</style>` : '';
    await page.setContent(`<html><head>${fontCss}<style>html,body{margin:0;background:transparent}svg{display:block;width:${j.w * scale}px;height:${j.h * scale}px}</style></head><body>${svg}</body></html>`);
    await page.evaluate(() => document.fonts.ready);
    await page.screenshot({ path: j.png, omitBackground: true });
  }
  await browser.close();
})();
