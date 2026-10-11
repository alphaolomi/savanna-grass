/**
 * Serves the Flutter web build and the locally downloaded Gemma weights from
 * one origin, so recording takes never re-download 550 MB from Hugging Face.
 *
 *   bun demo/serve.ts            # http://localhost:8090
 */
import { file } from "bun";
import { join, normalize } from "node:path";

const root = new URL("../build/web/", import.meta.url).pathname.replace(/^\/(\w:)/, "$1");
const models = new URL("./out/models/", import.meta.url).pathname.replace(/^\/(\w:)/, "$1");

Bun.serve({
  port: Number(process.env.PORT ?? 8090),
  async fetch(req) {
    const path = decodeURIComponent(new URL(req.url).pathname);
    const [dir, rel] = path.startsWith("/models/")
      ? [models, path.slice("/models/".length)]
      : [root, path === "/" ? "index.html" : path.slice(1)];
    const target = normalize(join(dir, rel));
    if (!target.startsWith(normalize(dir))) return new Response("no", { status: 403 });
    const f = file(target);
    if (!(await f.exists())) return new Response("not found", { status: 404 });
    return new Response(f, { headers: { "cache-control": "no-store" } });
  },
});
console.log("Serving build/web and demo/out/models on http://localhost:" + (process.env.PORT ?? 8090));
