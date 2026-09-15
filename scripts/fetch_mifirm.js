// Generic stock-ROM download helper for mifirm.net.
// Usage: node fetch_mifirm.js <mifirm_download_id> <download_type>
//   download_type: download_mi1|mi2|mi3|mi4|download_mifirm|download_gg|download_afh|download_sf
// Prints JSON with the mirror URL (MIRRORS[0].url) from the mifirm /downloadnow API.
// Requires: puppeteer (npm i puppeteer) + a browser binary (npx @puppeteer/browsers install chrome-headless-shell).
const puppeteer = require('puppeteer');
(async () => {
  const id = process.argv[2], dtype = process.argv[3] || 'download_mi1';
  const browser = await puppeteer.launch({
    headless: 'shell',
    args: ['--no-sandbox', '--disable-gpu', '--disable-dev-shm-usage'],
  });
  const page = await browser.newPage();
  await page.setUserAgent('Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/153.0.0.0 Safari/537.36');
  try {
    await page.goto(`https://mifirm.net/download/${id}`, { waitUntil: 'domcontentloaded', timeout: 90000 });
  } catch (e) { console.error('goto warn: ' + e.message); }
  await new Promise(r => setTimeout(r, 15000));
  const res = await page.evaluate(async (id, dtype) => {
    if (typeof grecaptcha === 'undefined') return { err: 'no grecaptcha' };
    const tok = await grecaptcha.execute('6LcExcwZAAAAAAKx4rte0a0pRq1-03psf5AiRIFj', { action: 'download' });
    const csrf = document.querySelector('meta[name="csrf-token"]').content;
    const r = await fetch('/downloadnow', {
      method: 'POST',
      headers: {
        'X-CSRF-TOKEN': csrf,
        'X-Requested-With': 'XMLHttpRequest',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: `token=${encodeURIComponent(tok)}&id=${id}&type=fb&download_type=${dtype}`,
    });
    return { resp: await r.text() };
  }, id, dtype);
  console.log(JSON.stringify(res));
  await browser.close();
})().catch(e => { console.error('ERR: ' + e.message); process.exit(1); });
