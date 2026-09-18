import { chromium } from 'playwright';
import { expect } from 'playwright/test';

async function runScript() {
  const expected_version = process.argv[2];
  const browser = await chromium.launch();
  const page = await browser.newPage();
  let reachedPage = false;
  try {
    await page.goto('http://localhost:8086');
    reachedPage = true;
    await expect(page.getByText('hello.ipynb')).toBeVisible({ timeout: 60000 });
    if (expected_version) {
      console.log('expected JupyterLab version:', expected_version);
    }
  } finally {
    if (reachedPage) {
      try {
        await page.screenshot({path: './test_screenshot.png', scale: 'css', type: 'png'});
      } catch (err) {
        console.error(err);
      }
    }
    await browser.close();
  }
}

runScript().catch((err) => {
  console.error(err);
  process.exit(1);
});
