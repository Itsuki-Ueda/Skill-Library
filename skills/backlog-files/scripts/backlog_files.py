"""Backlog の共有ファイルを一覧・ダウンロードする（標準ライブラリだけ）。

使い方:
  python backlog_files.py projects
  python backlog_files.py list <プロジェクトキー> [フォルダのパス]
  python backlog_files.py get  <プロジェクトキー> <ファイルID> [保存先フォルダ]

認証情報の読み方:
  1. 環境変数 BACKLOG_SPACE_URL（クラウド）。キーはネットワークシークレットが
     Backlog-API-Key ヘッダーを付けるので不要。環境変数 BACKLOG_API_KEY があればそれを使う
  2. 無ければ Windows の資格情報マネージャーの汎用資格情報 "backlog-api"
     （ユーザー名 = スペースの URL、パスワード = APIキー）
"""
import email.message
import json
import os
import re
import sys
import tempfile
import urllib.error
import urllib.parse
import urllib.request

CRED_TARGET = "backlog-api"


def read_windows_credential(target):
    import ctypes
    from ctypes import wintypes

    class CREDENTIAL(ctypes.Structure):
        _fields_ = [
            ("Flags", wintypes.DWORD), ("Type", wintypes.DWORD),
            ("TargetName", wintypes.LPWSTR), ("Comment", wintypes.LPWSTR),
            ("LastWritten", wintypes.FILETIME),
            ("CredentialBlobSize", wintypes.DWORD),
            ("CredentialBlob", ctypes.POINTER(ctypes.c_ubyte)),
            ("Persist", wintypes.DWORD), ("AttributeCount", wintypes.DWORD),
            ("Attributes", ctypes.c_void_p), ("TargetAlias", wintypes.LPWSTR),
            ("UserName", wintypes.LPWSTR),
        ]

    advapi32 = ctypes.WinDLL("advapi32", use_last_error=True)
    pcred = ctypes.POINTER(CREDENTIAL)()
    if not advapi32.CredReadW(target, 1, 0, ctypes.byref(pcred)):  # 1 = CRED_TYPE_GENERIC
        return None
    try:
        cred = pcred.contents
        blob = ctypes.string_at(cred.CredentialBlob, cred.CredentialBlobSize)
        # cmdkey は UTF-16LE で保存する
        return cred.UserName, blob.decode("utf-16-le")
    finally:
        advapi32.CredFree(pcred)


def load_credentials():
    url = os.environ.get("BACKLOG_SPACE_URL")
    if url:
        # キーが無ければ None のまま送り、ネットワークシークレットに付けてもらう
        return url, os.environ.get("BACKLOG_API_KEY")
    if os.name == "nt":
        found = read_windows_credential(CRED_TARGET)
        if found and found[0] and found[1]:
            return found
    sys.exit(
        "Backlog の認証情報が見つかりません。\n"
        "  クラウド: 環境変数 BACKLOG_SPACE_URL を設定し、キーはネットワークシークレット（ヘッダー Backlog-API-Key）で渡す\n"
        f"  Windows : cmdkey /generic:{CRED_TARGET} /user:{{スペースのURL}} /pass:{{APIキー}}"
    )


def api_url(space_url, path, **params):
    base = space_url.rstrip("/")
    if not base.startswith(("http://", "https://")):
        base = "https://" + base
    return f"{base}/api/v2/{path}?{urllib.parse.urlencode(params)}"


def request(url, key):
    headers = {"Backlog-API-Key": key} if key else {}
    try:
        return urllib.request.urlopen(urllib.request.Request(url, headers=headers), timeout=60)
    except urllib.error.HTTPError as e:
        sys.exit(f"Backlog API エラー {e.code}: {e.read().decode('utf-8', 'replace')[:500]}")


def list_files(space_url, key, project, folder):
    # Git Bash は先頭が / の引数を C:/Program Files/Git/... に書き換える。Backlog のパスがドライブ名で始まることはない
    if re.match(r"^[A-Za-z]:[/\\]", folder):
        sys.exit(f"フォルダのパスが PC の場所（{folder}）に書き換えられています。先頭の / を外して渡してください。")
    folder = "/" + folder.strip("/")
    path = f"projects/{urllib.parse.quote(project)}/files/metadata{urllib.parse.quote(folder)}"
    offset, items = 0, []
    while True:
        with request(api_url(space_url, path, order="asc", count=1000, offset=offset), key) as r:
            page = json.load(r)
        items += page
        if len(page) < 1000:
            return items
        offset += 1000


def safe_name(name):
    return "".join("_" if c in '<>:"/\\|?*' else c for c in name).strip() or "download"


def get_file(space_url, key, project, file_id, out_dir):
    path = f"projects/{urllib.parse.quote(project)}/files/{int(file_id)}"
    with request(api_url(space_url, path), key) as r:
        msg = email.message.Message()
        msg["content-disposition"] = r.headers.get("Content-Disposition", "")
        name = safe_name(msg.get_filename() or f"file-{file_id}")
        os.makedirs(out_dir, exist_ok=True)
        dest = os.path.join(out_dir, name)
        with open(dest, "wb") as f:
            while chunk := r.read(1 << 16):
                f.write(chunk)
    return dest


def list_projects(space_url, key):
    with request(api_url(space_url, "projects"), key) as r:
        return json.load(r)


def main(argv):
    if argv[1:2] != ["projects"] and (len(argv) < 3 or argv[1] not in ("list", "get")):
        sys.exit(__doc__)
    space_url, key = load_credentials()
    if argv[1] == "projects":
        for p in list_projects(space_url, key):
            print(f"{p['projectKey']}\t{p['name']}")
    elif argv[1] == "list":
        for it in list_files(space_url, key, argv[2], argv[3] if len(argv) > 3 else "/"):
            kind = "DIR " if it["type"] == "directory" else "FILE"
            size = it.get("size") or "-"
            print(f"{it['id']}\t{kind}\t{size}\t{it['updated']}\t{(it['dir'] + it['name']).lstrip('/')}")
    else:
        if len(argv) < 4:
            sys.exit(__doc__)
        out = argv[4] if len(argv) > 4 else os.path.join(tempfile.gettempdir(), "backlog-files")
        print(get_file(space_url, key, argv[2], argv[3], out))


if __name__ == "__main__":
    # エラーは stderr に出るので、両方を UTF-8 にそろえる（Git Bash で化けないように）
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")
    main(sys.argv)
