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
    // A corrupt branch-served result must fall back to the raw repository copy.
    // Route both requests locally so CI does not depend on GitHub availability.
    const fixture = await readFile(resolve(root, 'experiments/e47_ablation_results.json'), 'utf8');
    const localResults = new URL('/experiments/e47_ablation_results.json', url).href;
    const remoteResults = 'https://raw.githubusercontent.com/nicholaskouns-create/Identity/main/experiments/e47_ablation_results.json';
    const fallbackPage = await context.newPage();
    await fallbackPage.route(localResults, route => route.fulfill({
      status: 200, contentType: 'application/json', body: '{"seeds":8,"auc_by_seed":{}}'
    }));
    await fallbackPage.route(remoteResults, route => route.fulfill({
      status: 200, contentType: 'application/json',
      headers: {'access-control-allow-origin': '*'}, body: fixture
    }));
    await fallbackPage.goto(url);
    await fallbackPage.waitForFunction(() =>
      document.querySelector('#load-status')?.textContent.startsWith('Loaded 8 archived synthetic seeds.')
    );
    assert.ok((await fallbackPage.locator('#load-status').textContent()).includes('raw.githubusercontent.com'));
    assert.equal(await fallbackPage.locator('#data-panel').evaluate(el => el.hidden), false);
    assert.equal(await fallbackPage.locator('#results-body tr').count(), 4);
    await fallbackPage.close();
    console.log('ABLATION_BROWSER_FALLBACK_PASS');

    // Invalid JSON syntax must also fall back, not just a valid-but-invalid schema.
    const malformedPage = await context.newPage();
    await malformedPage.route(localResults, route => route.fulfill({
      status: 200, contentType: 'application/json', body: '{"seeds":'
    }));
    await malformedPage.route(remoteResults, route => route.fulfill({
      status: 200, contentType: 'application/json',
      headers: {'access-control-allow-origin': '*'}, body: fixture
    }));
    await malformedPage.goto(url);
    await malformedPage.waitForFunction(() =>
      document.querySelector('#load-status')?.textContent.startsWith('Loaded 8 archived synthetic seeds.')
    );
    assert.ok((await malformedPage.locator('#load-status').textContent()).includes('raw.githubusercontent.com'));
    assert.equal(await malformedPage.locator('#data-panel').evaluate(el => el.hidden), false);
    await malformedPage.close();
    console.log('ABLATION_BROWSER_INVALID_JSON_PASS');

    // When neither source is usable, expose an error instead of stale charts.
    const failurePage = await context.newPage();
    for (const source of [localResults, remoteResults]) {
      await failurePage.route(source, route => route.fulfill({
        status: 503, contentType: 'text/plain',
        headers: {'access-control-allow-origin': '*'}, body: 'Unavailable'
      }));
    }
    await failurePage.goto(url);
    await failurePage.waitForFunction(() =>
      document.querySelector('#load-status')?.classList.contains('error')
    );
    assert.match(await failurePage.locator('#load-status').textContent(), /Results could not be loaded/);
    assert.match(await failurePage.locator('#load-status').textContent(), /HTTP 503/);
    assert.equal(await failurePage.locator('#data-panel').evaluate(el => el.hidden), true);
    assert.equal(await failurePage.locator('#retry-load').isVisible(), true);
    console.log('ABLATION_BROWSER_FAILURE_PASS');

    // Recovery must work without a full-page reload after the sources return.
    await failurePage.unroute(localResults);
    await failurePage.unroute(remoteResults);
    await failurePage.locator('#retry-load').click();
    await failurePage.waitForFunction(() =>
      document.querySelector('#load-status')?.textContent.startsWith('Loaded 8 archived synthetic seeds.')
    );
    assert.equal(await failurePage.locator('#data-panel').evaluate(el => el.hidden), false);
    assert.equal(await failurePage.locator('#retry-load').isVisible(), false);
    assert.equal(await failurePage.locator('#results-body tr').count(), 4);
    await failurePage.close();
    console.log('ABLATION_BROWSER_RETRY_PASS');
    console.log('ABLATION_BROWSER_INTERACTION_PASS');
  } finally {
    if (browser) await browser.close();
    await new Promise(resolve => server.close(resolve));
  }
})().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
