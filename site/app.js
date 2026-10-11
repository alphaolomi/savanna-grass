// Progressive enhancement: point the download buttons at the newest release
// that ships the APK, and show its version and size. The static links in the
// page work without this.
(async () => {
  const meta = document.getElementById("release-meta");
  try {
    const res = await fetch("https://api.github.com/repos/alphaolomi/savanna-grass/releases?per_page=20", {
      headers: { Accept: "application/vnd.github+json" },
    });
    if (!res.ok) return;
    // The model mirror is a release too; only app releases carry the APK.
    const release = (await res.json()).find(
      (r) => !r.draft && (r.assets || []).some((a) => a.name === "savanna-grass.apk"),
    );
    if (!release) return;
    const apk = release.assets.find((a) => a.name === "savanna-grass.apk");
    document
      .querySelectorAll('a[href$="/savanna-grass.apk"]')
      .forEach((a) => (a.href = apk.browser_download_url));
    const mb = Math.round(apk.size / 1e6);
    meta.textContent =
      `${release.tag_name}${release.prerelease ? " (preview)" : ""} · ${mb} MB · ` +
      "Android 7.0+ (64-bit) · free and open source";
  } catch {
    // Offline or rate-limited: the static line stays.
  }
})();
