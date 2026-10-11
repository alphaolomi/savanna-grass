/**
 * Seeds a LOCAL SavannaTime server with a test account and one believable
 * workday of screen time, for recording the demo video.
 *
 *   bun demo/seed.ts http://localhost:3100
 *
 * Goes through the real API exactly as the desktop tracker does: register,
 * register a device, create productivity rules, then POST /activity/sync with
 * client-generated ids. The generated credentials are written to
 * demo/out/account.json (gitignored) — never to the console.
 */
import { mkdirSync, writeFileSync } from "node:fs";
import { randomBytes, randomUUID } from "node:crypto";

const base = (process.argv[2] ?? "http://localhost:3100").replace(/\/$/, "") + "/api/v1";
const email = `grass-demo-${Date.now()}@savanna-grass.test`;
const password = randomBytes(12).toString("base64url");
const timezone = Intl.DateTimeFormat().resolvedOptions().timeZone;

let token = "";
async function call(method: string, path: string, body?: unknown) {
  const res = await fetch(base + path, {
    method,
    headers: {
      "content-type": "application/json",
      ...(token ? { authorization: `Bearer ${token}` } : {}),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const json = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(`${method} ${path} → ${res.status} ${JSON.stringify(json)}`);
  return json as any;
}

token = (await call("POST", "/auth/register", { email, password })).token;
await call("PUT", "/me/timezone", { timezone });
const device = (await call("POST", "/devices/register", {
  name: "Demo laptop",
  os: "windows",
  timezone,
})).device;

// How SavannaTime classifies each app: -2 very distracting .. +2 very productive.
const apps: Record<string, { category: string; level: number }> = {
  Code: { category: "development", level: 2 },
  Figma: { category: "design", level: 1 },
  Slack: { category: "communication", level: 0 },
  YouTube: { category: "video", level: -2 },
  X: { category: "social", level: -2 },
};
for (const [matchValue, r] of Object.entries(apps)) {
  await call("POST", "/rules", {
    ruleType: "app",
    matchValue,
    category: r.category,
    productivity: r.level,
  });
}

// A long day: deep work broken up by the usual leaks, ending ten minutes ago.
const plan: [string, string, number][] = [
  ["Code", "grass_debt.dart — savanna-grass", 55],
  ["Slack", "#general", 12],
  ["Code", "app_state.dart — savanna-grass", 48],
  ["YouTube", "Lo-fi beats to code to", 22],
  ["Figma", "Savanna Grass — screens", 35],
  ["X", "Home / X", 18],
  ["Code", "quest.dart — savanna-grass", 62],
  ["Slack", "#hacktoberfest", 9],
  ["YouTube", "How MediaPipe runs LLMs on-device", 26],
  ["Code", "savanna_api.dart — savanna-grass", 44],
  ["X", "Notifications / X", 15],
];
const totalMin = plan.reduce((s, [, , m]) => s + m, 0);
let t = Date.now() - (totalMin + 10) * 60_000;
const logs = plan.map(([appName, windowTitle, minutes]) => {
  const start = new Date(t);
  t += minutes * 60_000;
  return {
    id: randomUUID(),
    appName,
    windowTitle,
    processName: appName.toLowerCase(),
    startTime: start.toISOString(),
    endTime: new Date(t).toISOString(),
    duration: minutes * 60,
  };
});
const sync = await call("POST", "/activity/sync", { deviceId: device.id, schemaVersion: 1, logs });

mkdirSync(new URL("./out/", import.meta.url), { recursive: true });
writeFileSync(
  new URL("./out/account.json", import.meta.url),
  JSON.stringify({ email, password, timezone }, null, 2),
);
console.log(
  `Seeded ${sync.accepted} blocks (${Math.floor(totalMin / 60)}h ${totalMin % 60}m) in ${timezone}. ` +
    `Credentials in demo/out/account.json.`,
);
