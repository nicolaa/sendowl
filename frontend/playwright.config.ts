import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  /* Maximum time one test can run for. */
  timeout: 30 * 1000,
  expect: {
    timeout: 5000
  },
  /* Run tests in files in parallel */
  fullyParallel: true,
  /* Fail the build on CI if you accidentally left test.only in the source code. */
  forbidOnly: !!process.env.CI,
  /* Retry on CI only */
  retries: process.env.CI ? 2 : 0,
  /* Opt out of parallel tests on CI. */
  workers: process.env.CI ? 1 : undefined,
  /* Reporter to use. See https://playwright.dev/docs/test-reporters */
  reporter: 'html',
  /* Shared settings for all the projects below. See https://playwright.dev/docs/api/class-testoptions. */
  use: {
    /* Base URL to use in actions like `await page.goto('/')`. */
    baseURL: 'http://localhost:5174',

    /* Collect trace when retrying the failed test. See https://playwright.dev/docs/trace-viewer */
    trace: 'on-first-retry',
  },

  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
  ],

  /* Run your local dev server before starting the tests */
  webServer: [
    {
      // `rbenv local` pins the Ruby version for local runs; it's tolerated-if-absent so CI
      // (which provisions Ruby via actions/setup-ruby, no rbenv) doesn't fail on it.
      command: 'cd ../api && (rbenv local 4.0.1 2>/dev/null || true) && RAILS_ENV=test bin/rails db:test:prepare db:seed && RAILS_ENV=test bin/rails s -p 3001',
      url: 'http://localhost:3001/api/v1/products',
      reuseExistingServer: !process.env.CI,
      timeout: 120 * 1000,
      env: {
        FRONTEND_URL: 'http://localhost:5174',
        // Isolate e2e's committed writes in their own database so they never pollute the
        // api_test DB that RSpec uses. See config/database.yml.
        TEST_DATABASE: 'api_e2e'
      }
    },
    {
      command: 'VITE_API_URL=http://localhost:3001/api/v1 npm run dev -- --port 5174',
      url: 'http://localhost:5174',
      reuseExistingServer: !process.env.CI,
      timeout: 120 * 1000,
    }
  ],
});
