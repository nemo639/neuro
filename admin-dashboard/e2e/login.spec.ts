import { test, expect } from '@playwright/test';

test.describe('Admin Dashboard - Login', () => {
  test('login page loads', async ({ page }) => {
    await page.goto('/login');
    await expect(page).toHaveURL(/\/login/);
    await expect(page.locator('input[type="email"]')).toBeVisible();
    await expect(page.locator('input[type="password"]')).toBeVisible();
  });

  test('rejects empty submission', async ({ page }) => {
    await page.goto('/login');
    const submit = page.locator('button[type="submit"]');
    await submit.click();
    // HTML5 validation prevents submission — still on /login
    await expect(page).toHaveURL(/\/login/);
  });

  test('rejects invalid credentials', async ({ page }) => {
    await page.goto('/login');
    await page.locator('input[type="email"]').fill('wrong@admin.com');
    await page.locator('input[type="password"]').fill('WrongPassword123');
    await page.locator('button[type="submit"]').click();
    // Should remain on login OR show error
    await page.waitForTimeout(3000);
    await expect(page).toHaveURL(/\/login/);
  });

  test('successful login redirects to dashboard', async ({ page }) => {
    await page.goto('/login');
    await page.locator('input[type="email"]').fill('admin@neuroverse.com');
    await page.locator('input[type="password"]').fill('Admin@1234');
    await page.locator('button[type="submit"]').click();
    await page.waitForURL(/\/dashboard/, { timeout: 15000 });
    await expect(page).toHaveURL(/\/dashboard/);
  });
});
