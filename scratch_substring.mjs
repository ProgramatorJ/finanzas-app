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

walkDir(projectDir, filePath => {
  if (filePath.endsWith('.dart')) {
    const content = fs.readFileSync(filePath, 'utf-8');
    if (content.includes('.substring')) {
      const lines = content.split('\n');
      lines.forEach((line, index) => {
        if (line.includes('.substring')) {
          console.log(`${filePath}:${index + 1}: ${line.trim()}`);
        }
      });
    }
  }
});
