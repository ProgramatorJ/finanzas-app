import puppeteer from 'puppeteer';

const URL = 'https://mi-gestor-prestamos.web.app';

async function run() {
  console.log('🚀 Launching browser to capture console errors...');
  const browser = await puppeteer.launch({
    headless: true,
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });

  const page = await browser.newPage();
  
  // Listen for console events
  page.on('console', msg => {
    const type = msg.type().toUpperCase();
    console.log(`[CONSOLE ${type}]: ${msg.text()}`);
  });

  // Listen for page errors
  page.on('pageerror', err => {
    console.log('[PAGE ERROR]:', err.stack || err.toString());
  });

  // Listen for unhandled promise rejections
  page.on('unhandledrejection', reason => {
    console.log('[UNHANDLED REJECTION]:', reason.stack || reason.message || reason.toString());
  });

  // Listen for failed requests
  page.on('requestfailed', request => {
    const failure = request.failure();
    console.log(`[REQUEST FAILED]: ${request.url()} - ${failure ? failure.errorText : 'unknown'}`);
  });

  try {
    await page.goto(URL, { waitUntil: 'networkidle0', timeout: 15000 });
    console.log('Page loaded.');
    await page.screenshot({ path: 'scratch/screenshot.png' });
    console.log('Screenshot saved to scratch/screenshot.png');
  } catch (error) {
    console.log('Page loading error:', error.message);
  } finally {
    await browser.close();
    console.log('Done.');
  }
}

run().catch(console.error);
