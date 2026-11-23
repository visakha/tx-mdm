"""Dev-only READ-ONLY forwarder: http://127.0.0.1:8010/api/* -> TARGET through an HTTP proxy.

Used to drive the UI on a machine that reaches the backend only through an HTTP forward proxy
(e.g. a Tailscale tunnel proxy). Every POST is refused, so nothing can start a job.

  python dev/forward_readonly.py http://<backend-host>:8000 http://<proxy-host>:<port>
  TXMDM_API_TARGET=http://127.0.0.1:8010 npx vite --port 5174
"""

import sys
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

TARGET = sys.argv[1].rstrip("/")
PROXY = sys.argv[2] if len(sys.argv) > 2 else ""
PORT = 8010
handlers: list[urllib.request.BaseHandler] = (
    [urllib.request.ProxyHandler({"http": PROXY})] if PROXY else []
)
OPENER = urllib.request.build_opener(*handlers)


class Forward(BaseHTTPRequestHandler):
    def do_GET(self) -> None:  # noqa: N802
        accept = self.headers.get("Accept", "*/*")
        request = urllib.request.Request(TARGET + self.path, headers={"Accept": accept})
        try:
            with OPENER.open(request, timeout=60) as response:
                code, body = response.status, response.read()
                ctype = response.headers.get("content-type", "")
        except urllib.error.HTTPError as exc:
            code, body, ctype = exc.code, exc.read(), exc.headers.get("content-type", "")
        except OSError as exc:
            code, body, ctype = 502, str(exc).encode("ascii", "replace"), "text/plain"
        self.send_response(code)
        self.send_header("content-type", ctype)
        self.end_headers()
        self.wfile.write(body)

    def do_POST(self) -> None:  # noqa: N802
        self.send_response(405)
        self.end_headers()
        self.wfile.write(b"POST blocked by the read-only dev forwarder")


if __name__ == "__main__":
    ThreadingHTTPServer(("127.0.0.1", PORT), Forward).serve_forever()
