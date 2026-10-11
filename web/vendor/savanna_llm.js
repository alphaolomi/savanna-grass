// Savanna Grass: the browser engine behind lib/ai/web_llm.dart.
//
// Creates MediaPipe's LlmInference once, streaming the weights straight out of
// the Cache API (where flutter_gemma stored them) instead of materialising a
// 700 MB Blob — several such blobs at once exhaust the browser's blob store
// and fail with "Failed to fetch". MediaPipe itself is served from
// ./mediapipe (tool/vendor_mediapipe.sh), so this works with the network off.
window.savannaLlm = {
  async create(cacheName, modelUrl, options) {
    const cache = await caches.open(cacheName);
    const response = await cache.match(modelUrl);
    if (!response || !response.body) throw new Error("The model is not in this browser's cache yet.");
    const fileset = await window.FilesetResolver.forGenAiTasks(
      new URL("mediapipe/wasm", document.baseURI).href,
    );
    return window.LlmInference.createFromOptions(fileset, {
      ...options,
      baseOptions: { modelAssetBuffer: response.body.getReader() },
    });
  },
};
