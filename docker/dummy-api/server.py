#!/usr/bin/env python3
import json
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


SERVICE_NAME = os.environ.get("SERVICE_NAME", "dummy")
HOST = os.environ.get("HOST", "0.0.0.0")
PORT = int(os.environ.get("PORT", "8080"))


class Handler(BaseHTTPRequestHandler):
    def _send_json(self, status: int, payload: dict) -> None:
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:
        if self.path.endswith("/v1/models"):
            self._send_json(
                200,
                {
                    "object": "list",
                    "data": [
                        {
                            "id": f"{SERVICE_NAME}-dummy-model",
                            "object": "model",
                            "owned_by": "bitnet-stack",
                        }
                    ],
                },
            )
            return

        self._send_json(
            200,
            {
                "service": SERVICE_NAME,
                "path": self.path,
                "status": "ok",
            },
        )

    def do_POST(self) -> None:
        self._send_json(
            200,
            {
                "service": SERVICE_NAME,
                "path": self.path,
                "status": "ok",
                "note": "dummy backend",
            },
        )

    def log_message(self, format: str, *args) -> None:
        return


if __name__ == "__main__":
    print(f"Starting {SERVICE_NAME} dummy server on {HOST}:{PORT}")
    ThreadingHTTPServer((HOST, PORT), Handler).serve_forever()
