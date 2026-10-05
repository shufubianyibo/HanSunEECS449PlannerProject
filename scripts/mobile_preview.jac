"""Preview the real MobUI source in a browser, connected to the running web API.
A dedicated static server avoids Jac 0.37.11's sibling-asset routing issue.
"""
import subprocess;
import os;
import functools;
import from http.server { ThreadingHTTPServer, SimpleHTTPRequestHandler }
import from pathlib { Path }
import from urllib.request { Request, urlopen }
import from urllib.error { HTTPError, URLError }

glob backend: str = os.environ.get("COMPASS_URL", "http://127.0.0.1:8000").rstrip("/");

obj PreviewHandler(SimpleHTTPRequestHandler) {
    override def do_POST {
        if not self.path.startswith("/function/") { self.send_error(404); return; }
        length = int(self.headers.get("Content-Length", "0"));
        if length > 65536 { self.send_error(413); return; }
        body = self.rfile.read(length);
        request = Request(backend + self.path, data=body, headers={"Content-Type": "application/json"}, method="POST");
        try {
            with urlopen(request, timeout=15) as response {
                result = response.read();
                self.send_response(response.status);
                self.send_header("Content-Type", "application/json");
                self.end_headers(); self.wfile.write(result);
            }
        } except HTTPError as exc {
            self.send_response(exc.code); self.send_header("Content-Type", "application/json");
            self.end_headers(); self.wfile.write(exc.read());
        } except (URLError, TimeoutError) { self.send_error(502, "Planner unavailable. Start jac run."); }
    }
}

with entry:__main__ {
    project = Path(__file__).resolve().parent.parent;
    subprocess.run(["jac", "build", "mobile", "--platform", "web"], cwd=str(project), check=True);
    source = project / ".jac" / "client" / "mobile" / "dist";
    index_path = source / "index.html";
    if not index_path.exists() { raise RuntimeError("Mobile build did not produce index.html."); }
    handler = functools.partial(PreviewHandler, directory=str(source));
    server = ThreadingHTTPServer(("127.0.0.1", 8012), handler);
    print("Mobile preview: http://127.0.0.1:8012 | Backend: " + backend);
    try { server.serve_forever(); }
    except KeyboardInterrupt { print("Mobile preview stopped."); }
    finally { server.server_close(); }
}
