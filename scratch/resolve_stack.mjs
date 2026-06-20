import fs from 'fs';
import { SourceMapConsumer } from 'source-map';

const rawSourceMap = JSON.parse(fs.readFileSync('build/web/main.dart.js.map', 'utf8'));

async function resolve(line, column) {
  try {
    await SourceMapConsumer.with(rawSourceMap, null, consumer => {
      const pos = consumer.originalPositionFor({
        line: line,
        column: column
      });
      console.log(`JS ${line}:${column} -> Dart ${pos.source}:${pos.line}:${pos.column} (${pos.name})`);
    });
  } catch (err) {
    console.error(`Error resolving ${line}:${column}:`, err.message);
  }
}

async function run() {
  console.log('Resolving stack trace lines...');
  await resolve(48382, 8);
  await resolve(5180, 5);
  await resolve(5182, 7);
  await resolve(47404, 3);
}

run().catch(console.error);
