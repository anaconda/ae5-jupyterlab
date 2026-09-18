import { chromium } from 'playwright';
import { expect } from 'playwright/test';

const browser = await chromium.launch();
const page = await browser.newPage();

const needles = [
  'Salt Lake City', 'Seattle', 'Houston', 'Washington',
  'Los Angeles', 'San Francisco', 'Detroit', 'Fort Worth',
];

async function waitForCities() {
  const deadline = Date.now() + 60000;
  while (Date.now() < deadline) {
    for (const frame of page.frames()) {
      try {
        if (await frame.evaluate(
          list => list.some(s => document.documentElement.outerHTML.includes(s)),
          needles
        )) return frame;
      } catch {}
    }
    await page.waitForTimeout(250);
  }
  throw new Error(`Timed out ${timeout}ms waiting for any of ${JSON.stringify(needles)}`);
}

async function waitForText(what, timeout = 5000) {
    await expect(page.getByText(what)).toBeVisible({ timeout: timeout });
}

async function clickByText(what, double = false) {
  const obj = page.getByText(what);
  if (double) { await obj.dblclick(); } else { await obj.click(); }
  await page.waitForTimeout(500);
}

async function clickByRole(what, name) {
  await page.getByRole(what, { name: name, exact: true }).click();
  await page.waitForTimeout(500);
}

let screenshotCount = 0;
async function screenshot() {
  screenshotCount += 1;
  const num = String(screenshotCount).padStart(2, '0');
  await page.screenshot({path: './test_screenshot' + num + '.png', scale: 'css', type: 'png'});
}

let code=0;
try {
  await page.goto('http://localhost:8086');
  await waitForText('Click to prepare' );
  await screenshot();
  await clickByText('Click to prepare');
  await waitForText('"default" prepared successfully.', 45000 );
  await screenshot();
  await clickByText('route_chord.', true);
  await clickByRole('menuitem', 'Run');
  await clickByRole('menuitem', 'Run All Cells');
  await waitForCities();
  await screenshot();
  await clickByRole('button', /Save and create checkpoint/);
  await clickByRole('menuitem', 'File');
  await clickByText('Close Tab');
  await clickByText('Convert To Pixi');
  await clickByRole('button', 'Convert');
  await waitForText('"default" prepared successfully.', 45000 );
  await screenshot();
  await clickByText('route_chord2.', true);
  await clickByRole('menuitem', 'Run');
  await clickByRole('menuitem', 'Run All Cells');
  await waitForCities();
  await screenshot();
  await clickByRole('button', /Save and create checkpoint/);
  await clickByRole('menuitem', 'File');
  await clickByText('Close Tab');
  await clickByRole('menuitem', 'Help');
  await clickByText('About JupyterLab');
  await waitForText('Version ' + process.argv[2] );
  await screenshot();
} catch (err) {
  console.error(err);
  await(screenshot());
  code=1;
} finally {
  await browser.close();
}
process.exit(code);

// runScript();
