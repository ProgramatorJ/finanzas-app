import fs from 'fs';
import path from 'path';

const projectDir = 'c:\\Users\\Windows 10\\Desktop\\projects Antigravity\\lib';

function walkDir(dir, callback) {
  fs.readdirSync(dir).forEach(f => {
    let dirPath = path.join(dir, f);
    let isDirectory = fs.statSync(dirPath).isDirectory();
    if (isDirectory) {
      walkDir(dirPath, callback);
    } else {
      callback(dirPath);
    }
  });
}

const terms = [
  'FirebaseOptions'
];

walkDir(projectDir, filePath => {
  if (filePath.endsWith('.dart')) {
    const content = fs.readFileSync(filePath, 'utf-8');
    terms.forEach(term => {
      if (content.toLowerCase().includes(term.toLowerCase())) {
        const lines = content.split('\n');
        lines.forEach((line, index) => {
          if (line.toLowerCase().includes(term.toLowerCase())) {
            console.log(`${filePath}:${index + 1} [term: ${term}]: ${line.trim()}`);
          }
        });
      }
    });
  }
});
