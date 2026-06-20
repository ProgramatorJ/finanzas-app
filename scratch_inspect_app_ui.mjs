import puppeteer from 'puppeteer';

const URL = 'https://mi-gestor-prestamos.web.app';
const EMAIL = 'admin@gestor.com';
const PASSWORD = 'admin123456';

const sleep = (ms) => new Promise(r => setTimeout(r, ms));

async function run() {
  console.log('🚀 Starting UI Inspection script...');
  const browser = await puppeteer.launch({
    headless: true,
    args: ['--no-sandbox', '--disable-setuid-sandbox']
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
    await page.screenshot({ path: 'C:\\Users\\Windows 10\\.gemini\\antigravity\\brain\\a56619c1-001f-476b-87ff-e191b42d1266\\ui_step2_dashboard.png' });

    console.log('3. Enabling Semantics...');
    await page.evaluate(() => {
      const placeholder = document.querySelector('flt-semantics-placeholder');
      if (placeholder) placeholder.click();
    });
    await sleep(4000);

    console.log('4. Clicking Clientes card...');
    const clickedClientes = await page.evaluate(() => {
      const elements = Array.from(document.querySelectorAll('[role="button"], [role="link"], flt-semantics'));
      const clientsEl = elements.find(el => {
        const isBtn = el.getAttribute('role') === 'button';
        const text = (el.textContent || el.getAttribute('aria-label') || '').toLowerCase();
        return isBtn && text.includes('clientes');
      });

      if (clientsEl) {
        clientsEl.click();
        return { success: true };
      }
      return { success: false };
    });
    console.log('Clicked Clientes:', clickedClientes);
    await sleep(6000);

    console.log('5. Clicking Sofia Florez...');
    const clickedSofia = await page.evaluate(() => {
      const elements = Array.from(document.querySelectorAll('[role="button"], [role="link"], flt-semantics'));
      const sofiaEl = elements.find(el => {
        const isBtn = el.getAttribute('role') === 'button';
        const text = (el.textContent || el.getAttribute('aria-label') || '');
        return isBtn && text.includes('Sofia Florez');
      });

      if (sofiaEl) {
        sofiaEl.click();
        return { success: true };
      }
      return { success: false };
    });
    console.log('Clicked Sofia:', clickedSofia);
    await sleep(6000);

    console.log('6. Clicking Credit (500.000)...');
    const clickedCredit = await page.evaluate(() => {
      const elements = Array.from(document.querySelectorAll('[role="button"], [role="link"], flt-semantics'));
      const creditEl = elements.find(el => {
        const isBtn = el.getAttribute('role') === 'button';
        const text = (el.textContent || el.getAttribute('aria-label') || '');
        return isBtn && text.includes('500.000');
      });

      if (creditEl) {
        creditEl.click();
        return { success: true };
      }
      return { success: false };
    });
    console.log('Clicked Credit:', clickedCredit);
    await sleep(8000);
    await page.screenshot({ path: 'C:\\Users\\Windows 10\\.gemini\\antigravity\\brain\\a56619c1-001f-476b-87ff-e191b42d1266\\ui_step6_credit_detail.png' });

    // Let's dump all interactive elements on the credit detail page to find where the edit button and other elements are
    const creditDetailElements = await page.evaluate(() => {
      return Array.from(document.querySelectorAll('[role="button"], [role="textfield"], [role="dialog"], flt-semantics'))
        .map(el => ({
          tagName: el.tagName,
          role: el.getAttribute('role'),
          ariaLabel: el.getAttribute('aria-label'),
          textContent: el.textContent ? el.textContent.substring(0, 100) : ''
        }));
    });
    console.log('Credit Detail Elements:', creditDetailElements);

    // Let's click "Editar Parámetros del Crédito"
    console.log('7. Clicking edit parameters button...');
    const clickedEdit = await page.evaluate(() => {
      const elements = Array.from(document.querySelectorAll('[role="button"], flt-semantics'));
      const editBtn = elements.find(el => {
        const label = el.getAttribute('aria-label') || '';
        return label.includes('Editar Parámetros del Crédito');
      });

      if (editBtn) {
        editBtn.click();
        return { success: true };
      }
      return { success: false };
    });
    console.log('Clicked Edit Button:', clickedEdit);
    await sleep(5000);
    await page.screenshot({ path: 'C:\\Users\\Windows 10\\.gemini\\antigravity\\brain\\a56619c1-001f-476b-87ff-e191b42d1266\\ui_step7_edit_dialog.png' });

    // Let's dump elements in the edit dialog to see what fields are rendered
    const editDialogElements = await page.evaluate(() => {
      return Array.from(document.querySelectorAll('[role="dialog"] [role="textfield"], [role="dialog"] [role="button"], [role="dialog"] flt-semantics'))
        .map(el => ({
          role: el.getAttribute('role'),
          ariaLabel: el.getAttribute('aria-label'),
          value: el.value || el.textContent
        }));
    });
    console.log('Edit Dialog Elements:', editDialogElements);

  } catch (error) {
    console.log('💥 ERROR IN UI INSPECTION:', error.message);
  } finally {
    await browser.close();
    console.log('🏁 Script finished.');
  }
}

run().catch(console.error);
