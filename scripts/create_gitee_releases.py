#!/usr/bin/env python3
"""Batch-create Gitee Releases from markdown files via API.

Usage:
    GITEE_TOKEN=xxx python scripts/create_gitele_releases.py
"""
import json
import os
import sys
import urllib.request
import urllib.error
from pathlib import Path

OWNER = "weifu0523"
REPO = "e-book-reading-platform"
API = f"https://gitee.com/api/v5/repos/{OWNER}/{REPO}"
DOCS = Path("docs/releases")

# Attachments per-tag. Each entry: (path, [list of files to upload]).
# Files must exist on disk; missing files are skipped with a warning.
ATTACHMENTS = {
    "v1.9.0-alpha": [
        "C:/Users/1/Desktop/zhiyue-setup-1.9.0-alpha.exe",
        "C:/Users/1/Desktop/zhiyue-1.9.0-alpha.apk",
    ],
}

# (tag, release title, notes file)
RELEASES = [
    ("v0.4.0",           "智阅 v0.4.0",           "release-notes-v0.4.0.md"),
    ("v0.5.0",           "智阅 v0.5.0",           "release-notes-v0.5.0.md"),
    ("v0.7.0-alpha",     "智阅 v0.7.0-alpha",     "release-notes-v0.7.0-alpha.md"),
    ("v0.8.0-alpha",     "智阅 v0.8.0-alpha",     "release-notes-v0.8.0-alpha.md"),
    ("v0.9.0-alpha",     "智阅 v0.9.0-alpha",     "release-notes-v0.9.0-alpha.md"),
    ("v0.9.1-alpha",     "智阅 v0.9.1-alpha",     "release-notes-v0.9.1-alpha.md"),
    ("v1.0.0",           "智阅 v1.0.0 GA",        "release-notes-v1.0.0.md"),
    ("v1.2.0-alpha",     "智阅 v1.2.0-alpha",     "release-notes-v1.2.0-alpha.md"),
    ("v1.3.0-alpha",     "智阅 v1.3.0-alpha",     "release-notes-v1.3.0-alpha.md"),
    ("v1.6.0-alpha",     "智阅 v1.6.0-alpha",     "release-notes-v1.6.0-alpha.md"),
    ("v1.7.0-alpha",     "智阅 v1.7.0-alpha",     "release-notes-v1.7.0-alpha.md"),
    ("v1.7.1-alpha",     "智阅 v1.7.1-alpha",     "release-notes-v1.7.1-alpha.md"),
    ("v1.8.0-alpha",     "智阅 v1.8.0-alpha",     "release-notes-v1.8.0-alpha.md"),
    ("v1.9.0-alpha",     "智阅 v1.9.0-alpha",     "release-notes-v1.9.0-alpha.md"),
]


def create_release(token, tag, name, body):
    payload = {
        "access_token": token,
        "tag_name": tag,
        "name": name,
        "body": body,
        "target_commitish": "master",
    }
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        f"{API}/releases",
        data=data,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        err_body = e.read().decode("utf-8", errors="replace")
        return {"_error": f"HTTP {e.code}", "_body": err_body}
    except Exception as e:
        return {"_error": str(e)}


def upload_attachment(token, release_id, file_path):
    """multipart/form-data upload via stdlib."""
    boundary = "----GiteeBoundary7MA4YWxkTrZu0gW"
    with open(file_path, "rb") as f:
        file_bytes = f.read()
    filename = Path(file_path).name
    parts = []
    parts.append(f"--{boundary}\r\n".encode())
    parts.append(b'Content-Disposition: form-data; name="access_token"\r\n\r\n')
    parts.append(token.encode() + b"\r\n")
    parts.append(f"--{boundary}\r\n".encode())
    parts.append(
        f'Content-Disposition: form-data; name="name"\r\n\r\n{filename}\r\n'.encode()
    )
    parts.append(f"--{boundary}\r\n".encode())
    parts.append(
        f'Content-Disposition: form-data; name="file"; filename="{filename}"\r\n'.encode()
    )
    parts.append(b"Content-Type: application/octet-stream\r\n\r\n")
    parts.append(file_bytes + b"\r\n")
    parts.append(f"--{boundary}--\r\n".encode())
    body = b"".join(parts)
    req = urllib.request.Request(
        f"{API}/releases/{release_id}/attach_files",
        data=body,
        headers={"Content-Type": f"multipart/form-data; boundary={boundary}"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        err_body = e.read().decode("utf-8", errors="replace")
        return {"_error": f"HTTP {e.code}", "_body": err_body}
    except Exception as e:
        return {"_error": str(e)}


def main():
    token = os.environ.get("GITEE_TOKEN")
    if not token:
        sys.exit("GITEE_TOKEN env var required")

    results = []
    release_ids = {}
    for tag, name, fname in RELEASES:
        notes_path = DOCS / fname
        if not notes_path.exists():
            results.append((tag, "MISSING_NOTES", str(notes_path)))
            continue
        body = notes_path.read_text(encoding="utf-8")
        resp = create_release(token, tag, name, body)
        if "_error" in resp:
            results.append((tag, f"FAIL {resp['_error']}", resp.get("_body", "")[:200]))
        else:
            results.append((tag, f"OK id={resp.get('id')}", resp.get("name", "")))
            release_ids[tag] = resp.get("id")

    for tag, files in ATTACHMENTS.items():
        release_id = release_ids.get(tag)
        if not release_id:
            results.append((f"attach:{tag}", "SKIPPED", "no release id (create failed?)"))
            continue
        for fpath in files:
            p = Path(fpath)
            if not p.exists():
                results.append((f"attach:{tag}:{p.name}", "SKIPPED", f"file not found: {fpath}"))
                continue
            print(f"\nUploading {p.name} to {tag} (release {release_id})...")
            resp = upload_attachment(token, release_id, p)
            if "_error" in resp:
                results.append((f"attach:{tag}:{p.name}", f"FAIL {resp['_error']}", resp.get("_body", "")[:200]))
            else:
                results.append((f"attach:{tag}:{p.name}", "OK", resp.get("browser_download_url", str(resp)[:200])))

    print("\n=== Results ===")
    for r in results:
        print(f"  {r[0]:<30} {r[1]:<35} {r[2][:80]}")


if __name__ == "__main__":
    main()
