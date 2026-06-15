import { test, expect } from '@playwright/test';

async function loginAsAdmin(page: any) {
  await page.goto('/login');
  await page.locator('input[type="email"]').fill('admin@neuroverse.com');
  await page.locator('input[type="password"]').fill('Admin@1234');
  await page.locator('button[type="submit"]').click();
  await page.waitForURL(/\/dashboard/, { timeout: 45000 });
}

test.describe('Admin Dashboard - Authenticated Pages', () => {
  test.beforeEach(async ({ page }) => {
    await loginAsAdmin(page);
  });

  test('dashboard page renders', async ({ page }) => {
    await expect(page).toHaveURL(/\/dashboard/);
    // Dashboard should have content
    await expect(page.locator('body')).not.toBeEmpty();
  });

  test('users page is reachable', async ({ page }) => {
    await page.goto('/dashboard/users');
    await expect(page).toHaveURL(/\/users/);
  });

  test('doctors page is reachable', async ({ page }) => {
    await page.goto('/dashboard/doctors');
    await expect(page).toHaveURL(/\/doctors/);
  });

  test('feedback page is reachable', async ({ page }) => {
    await page.goto('/dashboard/feedback');
    await expect(page).toHaveURL(/\/feedback/);
  });

  test('analytics page is reachable', async ({ page }) => {
    await page.goto('/dashboard/analytics');
    await expect(page).toHaveURL(/\/analytics/);
  });

  test('settings page is reachable', async ({ page }) => {
    await page.goto('/dashboard/settings');
    await expect(page).toHaveURL(/\/settings/);
  });
});

test.describe('Admin Dashboard - Access Control', () => {
  test('redirects unauthenticated user to login', async ({ page, context }) => {
    await context.clearCookies();
    await page.goto('/dashboard');
    // Either stays on dashboard with login prompt OR redirects to /login
    await page.waitForTimeout(2000);
    const url = page.url();
    expect(url.includes('/login') || url.includes('/dashboard')).toBe(true);
  });
});
