import fs from 'fs';
import path from 'path';

const projectDir = 'c:\\Users\\Windows 10\\Desktop\\projects Antigravity\\lib';

function walkDir(dir) {
  fs.readdirSync(dir).forEach(f => {
    let dirPath = path.join(dir, f);
    let isDirectory = fs.statSync(dirPath).isDirectory();
    if (isDirectory) {
      walkDir(dirPath);
    } else {
      if (dirPath.endsWith('.dart')) {
        console.log(dirPath);
      }
    }
  });
}

walkDir(projectDir);
