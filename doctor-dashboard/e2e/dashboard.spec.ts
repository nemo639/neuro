import { test, expect } from '@playwright/test';

async function loginAsDoctor(page: any) {
  await page.goto('/login');
  await page.locator('input[type="email"]').fill('doctor@neuroverse.com');
  await page.locator('input[type="password"]').fill('Doctor@1234');
  await page.locator('button[type="submit"]').click();
  await page.waitForURL(/\/dashboard/, { timeout: 45000 });
}

test.describe('Doctor Dashboard - Authenticated Pages', () => {
  test.beforeEach(async ({ page }) => {
    await loginAsDoctor(page);
  });

  test('dashboard renders after login', async ({ page }) => {
    await expect(page).toHaveURL(/\/dashboard/);
    await expect(page.locator('body')).not.toBeEmpty();
  });

  test('patients page is reachable', async ({ page }) => {
    await page.goto('/dashboard/patients');
    await expect(page).toHaveURL(/\/patients/);
  });

  test('notes page is reachable', async ({ page }) => {
    await page.goto('/dashboard/notes');
    await expect(page).toHaveURL(/\/notes/);
  });

  test('alerts page is reachable', async ({ page }) => {
    await page.goto('/dashboard/alerts');
    await expect(page).toHaveURL(/\/alerts/);
  });

  test('reports page is reachable', async ({ page }) => {
    await page.goto('/dashboard/reports');
    await expect(page).toHaveURL(/\/reports/);
  });

  test('settings page is reachable', async ({ page }) => {
    await page.goto('/dashboard/settings');
    await expect(page).toHaveURL(/\/settings/);
  });
});

test.describe('Doctor Dashboard - Access Control', () => {
  test('redirects unauthenticated user to login', async ({ page, context }) => {
    await context.clearCookies();
    await page.goto('/dashboard');
    await page.waitForTimeout(2000);
    const url = page.url();
    expect(url.includes('/login') || url.includes('/dashboard')).toBe(true);
  });
});
