import { test, expect } from '@playwright/test';

test('Simulate purchase and download flow', async ({ page }) => {
  // 1. Go to the dashboard
  await page.goto('/');

  // 1b. Wait for the data to load so the product dropdown is populated
  await expect(page.locator('text=Loading data...')).toBeHidden();

  // 2. Fill the email and click the "Complete Purchase" button
  await page.fill('input#email', 'test@playwright.com');
  await page.click('button:has-text("Complete Purchase")');

  // 3. Wait for the success message to confirm the order was placed
  await expect(page.locator('text=Order created for test@playwright.com!')).toBeVisible();

  // 4. Fetch the latest email from the backend test route
  // Scoped to this test's buyer so it stays correct when specs run in parallel against the shared DB.
  const emailRes = await page.request.get('http://localhost:3001/test/latest_email?to=test@playwright.com');
  const emailHtml = await emailRes.text();
  const urlMatch = emailHtml.match(/href="(http:\/\/localhost:5174\/download\/[^"]+)"/);
  expect(urlMatch).toBeTruthy();
  const href = urlMatch![1];

  // 5. Navigate to the download landing page
  await page.goto(href!);

  // 6. Verify the landing page rendered correctly
  await expect(page.locator('h2', { hasText: 'Download Ready' })).toBeVisible();
  await expect(page.locator('text=Downloads remaining:')).toBeVisible();

  // 7. Click the "Download Now" button and assert we are redirected to example.com
  // The button fires a POST request, and on success, sets window.location.href
  await Promise.all([
    page.waitForURL(/example\.com/),
    page.click('button:has-text("Download Now")')
  ]);

  // Final assertion to prove the entire flow worked
  expect(page.url()).toContain('example.com/downloads/');

  // 8. Go back to dashboard and click Resend Link
  await page.goto('/');
  await expect(page.locator('text=Loading data...')).toBeHidden();

  // Locate this test's own order by its buyer email rather than assuming it is the first row,
  // so the assertions are correct even when other specs create orders concurrently.
  const myRow = page.locator('table tbody tr', { hasText: 'test@playwright.com' });

  // This order should have 1 / 3 downloads
  await expect(myRow.locator('td').nth(4)).toContainText('1 / 3');

  // Click Resend Link for this order
  await myRow.getByRole('button', { name: 'Resend Link' }).click();
  await expect(page.locator('text=Order created for test@playwright.com!')).toBeVisible();

  // Still 1 / 3 downloads (count is preserved on resend)
  await expect(myRow.locator('td').nth(4)).toContainText('1 / 3');

  // 9. Fetch the new email (scoped to this test's buyer)
  const emailRes2 = await page.request.get('http://localhost:3001/test/latest_email?to=test@playwright.com');
  const emailHtml2 = await emailRes2.text();
  const urlMatch2 = emailHtml2.match(/href="(http:\/\/localhost:5174\/download\/[^"]+)"/);
  expect(urlMatch2).toBeTruthy();
  const href2 = urlMatch2![1];

  // 10. Navigate to new link and download
  await page.goto(href2!);
  await Promise.all([
    page.waitForURL(/example\.com/),
    page.click('button:has-text("Download Now")')
  ]);

  // 11. Go back and verify this order updated to 2 / 3 (by refreshing)
  await page.goto('/');
  await expect(page.locator('text=Loading data...')).toBeHidden();
  await expect(page.locator('table tbody tr', { hasText: 'test@playwright.com' }).locator('td').nth(4)).toContainText('2 / 3');
});
