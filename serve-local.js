// ============================================================
//  VelocityIQ - local dev server (zero dependencies)
//  Serves velocityiq.html at http://localhost:8080/
//  Run:  node serve-local.js   (optional:  node serve-local.js 3000)
// ============================================================
const http = require("http");
const fs = require("fs");
const path = require("path");
const os = require("os");

const PORT = parseInt(process.argv[2], 10) || 8080;
const ROOT = __dirname;
const DEMO = "velocityiq.html";

// Find this machine's LAN IPv4 addresses (for opening on phone / other devices)
function lanIPs() {
  const out = [];
  const ifaces = os.networkInterfaces();
  for (const name of Object.keys(ifaces)) {
    for (const ni of ifaces[name] || []) {
      if (ni.family === "IPv4" && !ni.internal) out.push(ni.address);
    }
  }
  return out;
}

const TYPES = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".svg": "image/svg+xml",
  ".png": "image/png",
  ".ico": "image/x-icon"
};

// --- live-reload client injected into every served HTML page ---
const LIVE_RELOAD = `
<script>
(function () {
  try {
    var es = new EventSource("/__livereload");
    es.onmessage = function (e) { if (e.data === "reload") location.reload(); };
  } catch (e) {}
})();
</script>`;

// --- connected browser tabs (Server-Sent Events) --------------
const clients = new Set();
function notifyReload() {
  for (const res of clients) { try { res.write("data: reload\n\n"); } catch (e) {} }
}

// --- watch the folder and push a reload when the demo changes --
let debounce = null;
try {
  fs.watch(ROOT, { persistent: true }, function (evt, filename) {
    if (filename && filename !== DEMO) return;   // only react to the demo file
    clearTimeout(debounce);
    debounce = setTimeout(function () {
      console.log("  change detected -> refreshing browser");
      notifyReload();
    }, 120);
  });
} catch (e) {
  console.log("  (live file-watch unavailable — manual refresh still works)");
}

const server = http.createServer((req, res) => {
  let urlPath = decodeURIComponent(req.url.split("?")[0]);

  // Live-reload event stream
  if (urlPath === "/__livereload") {
    res.writeHead(200, {
      "Content-Type": "text/event-stream",
      "Cache-Control": "no-cache",
      "Connection": "keep-alive"
    });
    res.write("retry: 1000\n\n");
    clients.add(res);
    req.on("close", () => clients.delete(res));
    return;
  }

  if (urlPath === "/" || urlPath === "") urlPath = "/" + DEMO;

  // resolve safely inside ROOT (no path traversal)
  const filePath = path.join(ROOT, path.normalize(urlPath));
  if (!filePath.startsWith(ROOT)) {
    res.writeHead(403); return res.end("Forbidden");
  }

  fs.readFile(filePath, (err, data) => {
    if (err) {
      res.writeHead(404, { "Content-Type": "text/html; charset=utf-8" });
      return res.end('<h1>404</h1><p>Open <a href="/">the demo</a>.</p>');
    }
    const ext = path.extname(filePath).toLowerCase();
    if (ext === ".html") {
      let html = data.toString("utf8");
      html = html.includes("</body>")
        ? html.replace("</body>", LIVE_RELOAD + "\n</body>")
        : html + LIVE_RELOAD;
      res.writeHead(200, { "Content-Type": TYPES[".html"], "Cache-Control": "no-store" });
      return res.end(html);
    }
    res.writeHead(200, {
      "Content-Type": TYPES[ext] || "application/octet-stream",
      "Cache-Control": "no-store"   // always serve the latest edit
    });
    res.end(data);
  });
});

server.listen(PORT, "0.0.0.0", () => {
  const ips = lanIPs();
  console.log("");
  console.log("  VelocityIQ demo is running (with LIVE RELOAD):");
  console.log("");
  console.log("  On THIS computer:");
  console.log("      http://localhost:" + PORT + "/");
  console.log("");
  if (ips.length) {
    console.log("  On your PHONE / other devices (same Wi-Fi):");
    ips.forEach(ip => console.log("      http://" + ip + ":" + PORT + "/"));
  } else {
    console.log("  (No LAN IP found — connect this PC to Wi-Fi/network to share on phone.)");
  }
  console.log("");
  console.log("  Phone can't connect? Allow the port once (run as Administrator):");
  console.log('      netsh advfirewall firewall add rule name="VelocityIQ ' + PORT +
              '" dir=in action=allow protocol=TCP localport=' + PORT);
  console.log("");
  console.log("  Edit velocityiq.html and save — the browser refreshes itself.");
  console.log("  Leave this window open. Press Ctrl+C to stop.");
});

