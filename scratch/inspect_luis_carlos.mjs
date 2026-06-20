import puppeteer from 'puppeteer';

const URL = 'https://mi-gestor-prestamos.web.app';
const EMAIL = 'admin@gestor.com';
const PASSWORD = 'admin123456';

const sleep = (ms) => new Promise(r => setTimeout(r, ms));

async function run() {
  console.log('🚀 Starting inspection for Luis Carlos Montenegro...');
  const browser = await puppeteer.launch({
    headless: true,
    args: ['--non-interactive', '--no-sandbox', '--disable-setuid-sandbox']
  });

  const page = await browser.newPage();
  await page.setViewport({ width: 1366, height: 768 });

  try {
    console.log('1. Navigating to', URL);
    await page.goto(URL, { waitUntil: 'domcontentloaded' });
    await sleep(6000);

    console.log('2. Logging in...');
    await page.mouse.click(683, 384);
    await sleep(500);
    await page.keyboard.press('Tab');
    await sleep(300);
    await page.keyboard.type(EMAIL);
    await page.keyboard.press('Tab');
    await sleep(300);
    await page.keyboard.type(PASSWORD);
    await page.keyboard.press('Enter');
    await sleep(10000);

    console.log('3. Enabling Semantics...');
    await page.evaluate(() => {
      const placeholder = document.querySelector('flt-semantics-placeholder');
      if (placeholder) placeholder.click();
    });
    await sleep(4000);

    console.log('4. Clicking Clientes...');
    await page.evaluate(() => {
      const elements = Array.from(document.querySelectorAll('[role="button"], flt-semantics'));
      const clientsEl = elements.find(el => {
        const text = (el.textContent || el.getAttribute('aria-label') || '').toLowerCase();
        return text.includes('clientes');
      });
      if (clientsEl) clientsEl.click();
    });
    await sleep(6000);

    console.log('5. Clicking Luis Carlos Montenegro...');
    await page.evaluate(() => {
      const elements = Array.from(document.querySelectorAll('[role="button"], flt-semantics'));
      const luisEl = elements.find(el => {
        const text = (el.textContent || el.getAttribute('aria-label') || '');
        return text.includes('Luis Carlos Montenegro');
      });
      if (luisEl) luisEl.click();
    });
    await sleep(6000);

    console.log('6. Clicking Credit (26021001)...');
    await page.evaluate(() => {
      const elements = Array.from(document.querySelectorAll('[role="button"], flt-semantics'));
      const creditEl = elements.find(el => {
        const text = (el.textContent || el.getAttribute('aria-label') || '');
        return text.includes('26021001') || text.includes('1.000.000'); // Let's check for Luis's credit
      });
      if (creditEl) creditEl.click();
    });
    await sleep(8000);

    console.log('7. Dumping all text on page to find Cuota 11...');
    const pageText = await page.evaluate(() => {
      return document.body.innerText;
    });
    
    console.log('--- Page text dump ---');
    console.log(pageText);
    console.log('----------------------');

    // Search specifically for Cuota 11
    const lines = pageText.split('\n');
    console.log('--- Filtering for lines near Cuota 11 ---');
    let foundIndex = -1;
    lines.forEach((line, idx) => {
      if (line.includes('Cuota 11') || line.includes('Cuota #11')) {
        foundIndex = idx;
      }
    });

    if (foundIndex !== -1) {
      console.log('Found Cuota 11 at line', foundIndex);
      for (let i = Math.max(0, foundIndex - 2); i < Math.min(lines.length, foundIndex + 20); i++) {
        console.log(`[L${i}]: ${lines[i]}`);
      }
    } else {
      console.log('Cuota 11 text not found directly. Printing all lines containing "Total:" or "Abono"');
      lines.forEach((line, idx) => {
        if (line.includes('Total:') || line.includes('Abonado') || line.includes('Mora:')) {
          console.log(`[L${idx}]: ${line}`);
        }
      });
    }

  } catch (error) {
    console.log('💥 ERROR IN INSPECTION:', error.message);
  } finally {
    await browser.close();
    console.log('🏁 Script finished.');
  }
}

run().catch(console.error);
