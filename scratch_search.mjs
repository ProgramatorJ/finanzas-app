import fs from 'fs';
import readline from 'readline';

async function searchUserMessages() {
  const fileStream = fs.createReadStream('C:\\Users\\Windows 10\\.gemini\\antigravity\\brain\\a56619c1-001f-476b-87ff-e191b42d1266\\.system_generated\\logs\\transcript.jsonl');
  const rl = readline.createInterface({
    input: fileStream,
    crlfDelay: Infinity
  });

  const steps = [];
  for await (const line of rl) {
    try {
      const parsed = JSON.parse(line);
      steps.push(parsed);
    } catch (e) {}
  }

  // Look for the last 5 USER_INPUT steps and the next few steps
  const userIndices = [];
  for (let i = 0; i < steps.length; i++) {
    if (steps[i].type === 'USER_INPUT') {
      userIndices.push(i);
    }
  }

  console.log(`Found ${userIndices.length} user inputs.`);
  // Print details for the last 3 user inputs
  const lastIndices = userIndices.slice(-4);
  for (const idx of lastIndices) {
    console.log(`=== USER INPUT at Step ${steps[idx].step_index} ===`);
    console.log(steps[idx].content);
    console.log("--- SUBSEQUENT MODEL RESPONSE ---");
    // Find the next model response
    for (let j = idx + 1; j < steps.length; j++) {
      if (steps[j].source === 'MODEL' && steps[j].type === 'PLANNER_RESPONSE') {
        console.log(steps[j].content || `Tool calls: ${steps[j].tool_calls?.map(tc => tc.name).join(', ')}`);
        break;
      }
    }
  }
}

searchUserMessages();
