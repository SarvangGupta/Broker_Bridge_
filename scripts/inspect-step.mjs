import fs from 'fs';
const text = fs.readFileSync('C:/Users/dell/.gemini/antigravity/brain/55f6d3db-452b-4c66-a287-12cc0f0e0593/.system_generated/logs/transcript.jsonl', 'utf8');
const lines = text.split('\n');
for (const line of lines) {
  if (line.includes('"step_index":2217')) {
    const obj = JSON.parse(line);
    console.log(JSON.stringify(obj.tool_calls, null, 2));
  }
}

