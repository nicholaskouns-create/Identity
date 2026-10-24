/** Browser-level regression test for the published ablation explorer.
 * Serves repository files locally; uses the archived synthetic JSON, not a mock.
 * Run: NODE_PATH=/tmp/identity-browser-deps/node_modules node tools/test-ablation-browser.cjs
 */
const assert = require('node:assert/strict');
const {createServer} = require('node:http');
const {readFile} = require('node:fs/promises');
const {resolve, extname, sep} = require('node:path');
const {chromium} = require('playwright');

const root = resolve(__dirname, '..');
const mime = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8'
};
const server = createServer(async (request, response) => {
  try {
    const pathname = decodeURIComponent(new URL(request.url, 'http://localhost').pathname);
    const path = resolve(root, '.' + pathname);
    if (!path.startsWith(root + sep)) {
      response.writeHead(403).end();
      return;
    }
    const bytes = await readFile(path);
    response.writeHead(200, {'Content-Type': mime[extname(path)] || 'application/octet-stream'}).end(bytes);
  } catch {
    response.writeHead(404).end('Not found');
  }
});

(async () => {
  let browser;
  try {
    await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
    const url = `http://127.0.0.1:${server.address().port}/site/ablation.html`;
    browser = await chromium.launch({headless: true});
    const context = await browser.newContext({acceptDownloads: true});
    const page = await context.newPage();
    await page.goto(url);
    await page.waitForFunction(() =>
      document.querySelector('#load-status')?.textContent.startsWith('Loaded 8 archived synthetic seeds.')
    );

    assert.equal(await page.locator('#data-panel').evaluate(el => el.hidden), false);
    assert.equal(await page.locator('#results-body tr').count(), 4);
    assert.equal(await page.locator('#seed-body tr').count(), 8);
    assert.equal(await page.locator('#bars [role="img"][aria-label]').count(), 4);
    assert.equal(await page.locator('#results-body th[scope="row"]').count(), 4);
    assert.equal(await page.locator('#seed-body th[scope="row"]').count(), 8);
    assert.match(await page.locator('#left-auc-header').textContent(), /E47-derived rank-24 AUC/);
    assert.match(await page.locator('#right-auc-header').textContent(), /Random rank-24 AUC/);

    // Keyboard activation must navigate to the focusable main landmark.
    await page.locator('.skip-link').focus();
    await page.keyboard.press('Enter');
    await page.waitForFunction(() => location.hash === '#ablation-main');
    assert.equal(await page.locator('main').evaluate(el => document.activeElement === el), true);

    // Native select change must update accessible column labels and paired rows.
    await page.locator('#arm-left').selectOption('baseline64');
    assert.match(await page.locator('#left-auc-header').textContent(), /Original 64D AUC/);
    assert.match(await page.locator('#comparison').textContent(), /Mean paired Δ AUC:/);
    assert.equal(await page.locator('#seed-body tr').count(), 8);

    const [download] = await Promise.all([
      page.waitForEvent('download'),
      page.locator('#export').click()
    ]);
    assert.equal(download.suggestedFilename(), 'e47-ablation-view.json');
    const exported = JSON.parse(await readFile(await download.path(), 'utf8'));
    assert.equal(exported.evidence_class, 'synthetic');
    assert.equal(exported.summary.seeds, 8);
    assert.equal(exported.paired_comparison.left, 'baseline64');
    assert.equal(exported.paired_comparison.right, 'random24');
    assert.equal(exported.paired_comparison.differences.length, 8);
    assert.equal(exported.archived_results.seeds, 8);
    console.log('ABLATION_BROWSER_INTERACTION_PASS');
  } finally {
    if (browser) await browser.close();
    await new Promise(resolve => server.close(resolve));
  }
})().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
