import { test, expect, chromium, webkit } from '@playwright/test';

test('Cross-browser resend flow', async () => {
  const chromeBrowser = await chromium.launch();
  const safariBrowser = await chromium.launch();

  const chromeContext = await chromeBrowser.newContext({ baseURL: 'http://localhost:5174' });
  const safariContext = await safariBrowser.newContext({ baseURL: 'http://localhost:5174' });

  const chromePage = await chromeContext.newPage();
  const safariPage = await safariContext.newPage();

  // 1. Chrome: Go to dashboard
  await chromePage.goto('/');
  await expect(chromePage.locator('text=Loading data...')).toBeHidden();

  // 2. Chrome: Fill purchase
  await chromePage.fill('input#email', 'test@cross.com');
  await chromePage.click('button:has-text("Complete Purchase")');
  await expect(chromePage.locator('text=Order created for test@cross.com!')).toBeVisible();

  // 3. Safari: Fetch email and download (scoped to this test's buyer for parallel-safety)
  const emailRes1 = await safariPage.request.get('http://localhost:3001/test/latest_email?to=test@cross.com');
  const emailHtml1 = await emailRes1.text();
  const href1 = emailHtml1.match(/href="(http:\/\/localhost:5174\/download\/[^"]+)"/)![1];

  await safariPage.goto(href1);
  await Promise.all([
    safariPage.waitForURL(/example\.com/),
    safariPage.click('button:has-text("Download Now")')
  ]);

  // 4. Chrome: Resend Link
  await chromePage.goto('/');
  await expect(chromePage.locator('text=Loading data...')).toBeHidden();

  // Locate this test's own order by buyer email so it isn't confused with orders from other specs.
  const chromeRow = chromePage.locator('table tbody tr', { hasText: 'test@cross.com' });
  await expect(chromeRow.locator('td').nth(4)).toContainText('1 / 3');

  await chromeRow.getByRole('button', { name: 'Resend Link' }).click();
  await expect(chromePage.locator('text=Order created for test@cross.com!')).toBeVisible();

  // 5. Safari: Fetch NEW email and download (scoped to this test's buyer)
  const emailRes2 = await safariPage.request.get('http://localhost:3001/test/latest_email?to=test@cross.com');
  const emailHtml2 = await emailRes2.text();
  const href2 = emailHtml2.match(/href="(http:\/\/localhost:5174\/download\/[^"]+)"/)![1];

  await safariPage.goto(href2);
  await Promise.all([
    safariPage.waitForURL(/example\.com/),
    safariPage.click('button:has-text("Download Now")')
  ]);

  // 6. Chrome: Verify this order reached 2 / 3
  await chromePage.goto('/');
  await expect(chromePage.locator('text=Loading data...')).toBeHidden();
  await expect(chromePage.locator('table tbody tr', { hasText: 'test@cross.com' }).locator('td').nth(4)).toContainText('2 / 3');

  await chromeBrowser.close();
  await safariBrowser.close();
});
