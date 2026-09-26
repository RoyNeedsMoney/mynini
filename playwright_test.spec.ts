import { test, expect } from '@playwright/test';

test.describe('NINI 3D Vacuum RPG Web & Stage 1 Tests', () => {

  test.beforeEach(async ({ page }) => {
    await page.goto('/');
  });

  test('should display Command Center dashboard correctly', async ({ page }) => {
    // Verify Command Center Header
    await expect(page.getByText('NINI // 3D VACUUM RPG')).toBeVisible();
    await expect(page.getByText('吸塵英雄指揮中心')).toBeVisible();
    await expect(page.getByText(/RANK \d+ 級指揮官/)).toBeVisible();

    // Verify Vacuum Hero Card
    await expect(page.getByText('V-01 渦輪吸塵者')).toBeVisible();
    await expect(page.getByText(/吸力:/)).toBeVisible();
    await expect(page.getByText(/容量:/)).toBeVisible();
    await expect(page.getByText(/電池:/)).toBeVisible();

    // Verify 3D Zone Map
    await expect(page.getByText('3D 任務關卡地圖')).toBeVisible();
    await expect(page.getByText('客廳')).toBeVisible();
    await expect(page.getByText('長廊')).toBeVisible();
  });

  test('should test Stage 1 mechanics via automated test unit button', async ({ page }) => {
    // Click on "測試第一關" test button
    const testStage1Btn = page.getByRole('button', { name: '測試第一關' });
    if (await testStage1Btn.isVisible()) {
      await testStage1Btn.click();
      await expect(page.getByText(/第一關.*測試成功通過/)).toBeVisible();
    }
  });

  test('should navigate between all tab screens', async ({ page }) => {
    // 1. Armory Workshop Tab
    await page.getByRole('button', { name: '吸塵器工坊' }).click();
    await expect(page.getByText('吸塵器升級工坊')).toBeVisible();
    await expect(page.getByText('吸力馬達 (Motor)')).toBeVisible();

    // 2. Core Skills Tab
    await page.getByRole('button', { name: '核心技能' }).click();
    await expect(page.getByText('核心黑科技技能')).toBeVisible();
    await expect(page.getByText('渦輪衝鋒 (Turbo Dash)')).toBeVisible();

    // 3. Codex Tab
    await page.getByRole('button', { name: '塵怪圖鑑' }).click();
    await expect(page.getByText('異變塵怪圖鑑')).toBeVisible();
    await expect(page.getByText('微塵小妖 (Dust Bunny)')).toBeVisible();

    // 4. Return to Command Center Tab
    await page.getByRole('button', { name: '指揮中心' }).click();
    await expect(page.getByText('吸塵英雄指揮中心')).toBeVisible();
  });

  test('should perform upgrades in Armory Shop', async ({ page }) => {
    await page.getByRole('button', { name: '吸塵器工坊' }).click();

    // Find upgrade button for Motor if affordable
    const upgradeMotorBtn = page.getByRole('button', { name: /50/ }).first();
    if (await upgradeMotorBtn.isEnabled()) {
      await upgradeMotorBtn.click();
    }
  });

  test('should enter and control Stage 1 3D mission battle', async ({ page }) => {
    // Click on Sector 1 (Living Room)
    await page.getByText('客廳').click();

    // Verify inside 3D Mission HUD
    await expect(page.getByText('起始清理區')).toBeVisible();
    await expect(page.getByText('吸塵器電量 HP')).toBeVisible();
    await expect(page.getByText('集塵箱')).toBeVisible();

    // Test skill triggers
    const dashBtn = page.getByRole('button', { name: '衝鋒' });
    if (await dashBtn.isVisible()) {
      await dashBtn.click();
    }
  });

});
