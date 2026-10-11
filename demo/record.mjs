/**
 * Drives the real Savanna Grass web build through the demo flow and records
 * it, frame by frame, over the Chrome DevTools screencast.
 *
 *   PLAYWRIGHT_DIR=<dir with node_modules/playwright> node demo/record.mjs
 *
 * Nothing is mocked: the app talks to a local SavannaTime server seeded by
 * demo/seed.ts, and quests come from Gemma running in the browser on WebGPU.
 * The one liberty is the break itself — Playwright shifts the page clock so a
 * 21-minute break fits in a few seconds of video, and the edit labels it as a
 * time-lapse.
 *
 * Output: demo/out/frames/*.jpg plus demo/out/frames.json (frame timestamps)
 * and demo/out/marks.json (scene start times), consumed by demo/edit.py.
 */
import { createRequire } from "node:module";
import { mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { homedir } from "node:os";

const require = createRequire(join(process.env.PLAYWRIGHT_DIR, "package.json"));
const { chromium } = require("playwright");

const here = new URL(".", import.meta.url).pathname.replace(/^\/(\w:)/, "$1");
const out = join(here, "out");
const framesDir = join(out, "frames");
rmSync(framesDir, { recursive: true, force: true });
mkdirSync(framesDir, { recursive: true });

const account = JSON.parse(readFileSync(join(out, "account.json"), "utf8"));
const APP = process.env.APP_URL ?? "http://localhost:8090/";
const shots = process.argv.includes("--shots");

// A fresh but *real* profile per take: signed out, no model cached. An
// in-memory (incognito-like) context has too little storage quota for the
// 700 MB model, so Cache API writes fail there. The model comes from
// demo/serve.ts on localhost, so the "one-time download" takes seconds.
const profile = join(homedir(), ".savanna-demo-tools", "take-profile");
rmSync(profile, { recursive: true, force: true });
const context = await chromium.launchPersistentContext(profile, {
  headless: false,
  viewport: { width: 412, height: 870 },
  deviceScaleFactor: 2,
  args: ["--enable-unsafe-webgpu", "--enable-features=Vulkan", "--window-size=460,1000"],
});
const page = context.pages()[0] ?? (await context.newPage());
page.on("console", (m) => {
  if (m.type() === "error" || m.text().startsWith("[quest]")) console.log("[page]", m.text().slice(0, 900));
});

// --- screencast ------------------------------------------------------------
const cdp = await context.newCDPSession(page);
const frames = [];
let t0 = null;
cdp.on("Page.screencastFrame", async ({ data, metadata, sessionId }) => {
  const ts = metadata.timestamp;
  t0 ??= ts;
  const name = `f${String(frames.length).padStart(5, "0")}.jpg`;
  writeFileSync(join(framesDir, name), Buffer.from(data, "base64"));
  frames.push({ name, t: ts - t0 });
  await cdp.send("Page.screencastFrameAck", { sessionId }).catch(() => {});
});
const marks = [];
const wall0 = { at: null };
function mark(name) {
  const t = wall0.at === null ? 0 : (Date.now() - wall0.at) / 1000;
  marks.push({ name, t });
  console.log(`mark ${name} @ ${t.toFixed(2)}s`);
}
async function shot(name) {
  if (shots) await page.screenshot({ path: join(out, `shot-${name}.png`) });
}

const sem = (role, name) => page.getByRole(role, { name, exact: false });
const pause = (ms) => page.waitForTimeout(ms);

// Flutter merges a card's text into the aria-label of a semantics group, so
// match against labels as well as text content.
async function waitText(re, timeout = 120_000) {
  try {
    await page.waitForFunction(
      ([src, flags]) => {
        const r = new RegExp(src, flags);
        return [...document.querySelectorAll("flt-semantics")].some(
          (e) => r.test(e.getAttribute("aria-label") ?? "") || r.test(e.textContent ?? ""),
        );
      },
      [re.source, re.flags],
      { timeout, polling: 200 },
    );
  } catch (e) {
    await page.screenshot({ path: join(out, "shot-failure.png") });
    throw e;
  }
}

// --- flow ------------------------------------------------------------------
await page.goto(APP);
await waitText(/Sign in with SavannaTime/);
await cdp.send("Page.startScreencast", { format: "jpeg", quality: 92, everyNthFrame: 1 });
wall0.at = Date.now();
mark("login");
await pause(1500);

await sem("textbox", "Email").click();
await pause(400); // let the field take focus, or the first key is lost
await page.keyboard.type(account.email, { delay: 25 });
await sem("textbox", "Password").click();
await pause(400);
await page.keyboard.type(account.password, { delay: 25 });
await pause(400);
await sem("button", "Sign in").click();
await waitText(/on screens/, 30_000);
await pause(800);
mark("home");
await shot("home");
await pause(9000);

// --no-model: pipeline dry run with the app's hand-written fallback quests.
if (!process.argv.includes("--no-model")) {
  if (await page.getByRole("button", { name: /Bring Twiga home/ }).count()) {
    mark("download");
    await sem("button", "Bring Twiga home").click();
  }
  await waitText(/On this device · works offline|couldn't make it/, 600_000);
  const failed = await page.evaluate(() =>
    [...document.querySelectorAll("flt-semantics")].some((e) =>
      /couldn't make it/.test((e.getAttribute("aria-label") ?? "") + (e.textContent ?? "")),
    ),
  );
  if (failed) {
    await page.screenshot({ path: join(out, "shot-failure.png") });
    throw new Error("Model download failed — see demo/out/shot-failure.png");
  }
}
mark("model-ready");
await pause(1200);

await sem("button", "Give me a quest").click();
mark("generating");
await waitText(/From Twiga|A classic quest/, 180_000);
mark("quest");
await shot("quest");
await pause(6500);

// Pull the plug. Gemma keeps working; only the SavannaTime refresh would fail.
await context.setOffline(true);
mark("offline");
await pause(1200);
await sem("button", "Another one").click();
await page.waitForTimeout(500);
await waitText(/From Twiga|A classic quest/, 180_000);
mark("quest-offline");
await shot("quest-offline");
await pause(6000);
await context.setOffline(false);
mark("online");

// Start the break 21 minutes in the past, then bring the clock back to now:
// the entry SavannaTime receives is a real, past 21-minute interval.
const realNow = Date.now();
await page.clock.setSystemTime(new Date(realNow - 21 * 60_000));
await sem("button", "going outside").click();
await waitText(/Phone in pocket|Quest time reached/);
mark("break");
await shot("break");
await pause(4500);
await page.clock.setSystemTime(new Date()); // back to real time: 21 min have "passed"
await pause(1200);
mark("later");
await shot("later");
await pause(1500);
await sem("textbox", "What did you notice").click();
await pause(500);
await page.keyboard.type("Counted 9 birds. My eyes feel lighter.", { delay: 45 });
await pause(800);
await sem("button", "back inside").click();
await waitText(/Logged to SavannaTime|Saved on this device/);
mark("logged");
await pause(2500);
await waitText(/Today outside/);
mark("home-after");
await shot("home-after");
await pause(3000);
await page.mouse.wheel(0, 900);
await pause(3500);
await page.mouse.wheel(0, -900);
await pause(800);

// Theme cycles system → light → dark.
mark("dark");
await page.getByRole("button", { name: /Theme:/ }).click();
await pause(300);
await page.getByRole("button", { name: /Theme:/ }).click();
await pause(3500);
await shot("dark");
mark("end");

await cdp.send("Page.stopScreencast");
await pause(300);
writeFileSync(join(out, "frames.json"), JSON.stringify(frames));
writeFileSync(join(out, "marks.json"), JSON.stringify(marks, null, 2));
console.log(`${frames.length} frames, ${marks.at(-1).t.toFixed(1)}s`);
await context.close();
