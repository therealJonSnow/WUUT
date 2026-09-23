/**
 * Screenshots each screen for comparison against Figma.
 *
 * Playwright is deliberately not a dependency — this is an occasional verification
 * tool, not part of the build. Install it when you need it:
 *
 *   npm run preview &
 *   npm install --no-save playwright && npx playwright install chromium
 *   node shoot.mjs
 *
 * Writes to /tmp. The primary Figma path does not need these — generate_figma_design
 * captures from a live URL — but they are useful for eyeballing a diff.
 */
import { chromium } from 'playwright'
// CHROMIUM_PATH is only needed where Playwright's bundled browser is unavailable
// (some CI and container images). On a normal machine the default is correct.
const executablePath = process.env.CHROMIUM_PATH
const browser = await chromium.launch(executablePath ? { executablePath } : {})
const page = await browser.newPage({ viewport: { width: 1800, height: 1100 }, deviceScaleFactor: 2 })
await page.goto('http://localhost:4173/', { waitUntil: 'networkidle' })
await page.screenshot({ path: '/tmp/harness-all.png', fullPage: true })
for (const label of ['Today', 'Week', 'Log entry', 'Settings']) {
  await page.getByRole('button', { name: label, exact: true }).click()
  await page.waitForTimeout(200)
  await page.locator('.screen').first().screenshot({
    path: `/tmp/screen-${label.toLowerCase().replace(' ', '-')}.png`,
  })
}
await browser.close()
console.log('shot')
