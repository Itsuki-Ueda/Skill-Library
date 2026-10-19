"""backlog_files の一覧と取得を偽の Backlog サーバーで確認する。実行: python test_backlog_files.py（pytest でも可）"""
import http.server
import json
import tempfile
import threading
import urllib.parse

import backlog_files

SEEN = []


class FakeBacklog(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def do_GET(self):
        u = urllib.parse.urlparse(self.path)
        q = urllib.parse.parse_qs(u.query)
        SEEN.append((u.path, q))
        assert q["apiKey"] == ["k"]
        if u.path == "/api/v2/projects/PRJ/files/metadata/%E8%B3%87%E6%96%99":
            body = json.dumps([{"id": 7, "type": "file", "dir": "/資料/", "name": "見積.pdf",
                                "size": 3, "updated": "2026-10-19T00:00:00Z"}]).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
        elif u.path == "/api/v2/projects/PRJ/files/7":
            body = b"PDF"
            self.send_response(200)
            self.send_header("Content-Disposition", "attachment; filename*=UTF-8''%E8%A6%8B%E7%A9%8D.pdf")
        else:
            body = b'{"errors":[{"message":"No such file."}]}'
            self.send_response(404)
        self.end_headers()
        self.wfile.write(body)


def test_list_and_get():
    srv = http.server.HTTPServer(("127.0.0.1", 0), FakeBacklog)
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    url = f"http://127.0.0.1:{srv.server_port}/"
    try:
        items = backlog_files.list_files(url, "k", "PRJ", "資料/")
        assert [i["name"] for i in items] == ["見積.pdf"]
        assert SEEN[-1][1]["count"] == ["1000"]
        with tempfile.TemporaryDirectory() as d:
            dest = backlog_files.get_file(url, "k", "PRJ", "7", d)
            assert dest.endswith("見積.pdf")
            assert open(dest, "rb").read() == b"PDF"
        try:
            backlog_files.get_file(url, "k", "PRJ", "8", tempfile.gettempdir())
            raise AssertionError("404 で止まるはず")
        except SystemExit as e:
            assert "404" in str(e) and "apiKey" not in str(e)
    finally:
        srv.shutdown()


if __name__ == "__main__":
    test_list_and_get()
    print("ok")
