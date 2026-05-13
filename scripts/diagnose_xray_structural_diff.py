#!/usr/bin/env python3
"""Read-only Xray rendered-vs-live structural diagnostic.

Compares two Xray JSON configs and prints only structural differences.
It never prints UUIDs, private keys, short IDs, tokens, client links, or full configs.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
from typing import Any, Iterable

SENSITIVE_KEY_NAMES = {
    "id",
    "uuid",
    "password",
    "pass",
    "email",
    "privatekey",
    "publickey",
    "shortid",
    "shortids",
    "token",
    "clientlink",
    "subscription",
    "uri",
    "link",
}

UUID_RE = re.compile(r"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$")
LONG_HEX_RE = re.compile(r"^[0-9a-fA-F]{12,}$")
LONG_BASE64ISH_RE = re.compile(r"^[A-Za-z0-9_+/=-]{24,}$")


def sha8_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()[:8]


def sha8_file(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()[:8]


def load_json(path: str) -> Any:
    with open(path, "r", encoding="utf-8") as handle:
        return json.load(handle)


def path_join(path: str, part: str) -> str:
    if not path:
        return part
    return path + "." + part


def is_sensitive_key(key: str) -> bool:
    return key.lower() in SENSITIVE_KEY_NAMES


def is_sensitive_string(value: str) -> bool:
    if UUID_RE.match(value):
        return True
    if LONG_HEX_RE.match(value):
        return True
    if LONG_BASE64ISH_RE.match(value):
        return True
    return False


def is_sensitive_path(path: str) -> bool:
    parts = [part.split("[")[0].lower() for part in path.split(".") if part]
    return any(part in SENSITIVE_KEY_NAMES for part in parts)


def canonical_redacted(value: Any, parent_key: str = "") -> Any:
    if is_sensitive_key(parent_key):
        if isinstance(value, list):
            return ["<redacted>" for _ in value]
        if isinstance(value, dict):
            return "<redacted_dict>"
        return "<redacted>"
    if isinstance(value, dict):
        return {key: canonical_redacted(value[key], key) for key in sorted(value)}
    if isinstance(value, list):
        return [canonical_redacted(item, parent_key) for item in value]
    if isinstance(value, str) and is_sensitive_string(value):
        return "<redacted>"
    return value


def canonical_json(value: Any) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=True).encode("utf-8")


def safe_value(path: str, value: Any) -> str:
    if is_sensitive_path(path):
        return "<redacted>"
    if isinstance(value, str) and is_sensitive_string(value):
        return "<redacted>"
    text = json.dumps(value, ensure_ascii=True, sort_keys=True)
    if len(text) > 120:
        return "<omitted_len_" + str(len(text)) + ">"
    return text


def diff_values(rendered: Any, live: Any, path: str = "") -> Iterable[str]:
    if type(rendered) is not type(live):
        yield "DIFF path=" + (path or "<root>") + " kind=type render_type=" + type(rendered).__name__ + " live_type=" + type(live).__name__
        return

    if isinstance(rendered, dict):
        keys = sorted(set(rendered) | set(live))
        for key in keys:
            child = path_join(path, key)
            if key not in rendered:
                yield "DIFF path=" + child + " kind=missing_in_render"
            elif key not in live:
                yield "DIFF path=" + child + " kind=missing_in_live"
            else:
                yield from diff_values(rendered[key], live[key], child)
        return

    if isinstance(rendered, list):
        if len(rendered) != len(live):
            yield "DIFF path=" + (path or "<root>") + " kind=list_length render=" + str(len(rendered)) + " live=" + str(len(live))
        for idx, (left, right) in enumerate(zip(rendered, live)):
            yield from diff_values(left, right, (path or "<root>") + "[" + str(idx) + "]")
        return

    if rendered != live:
        if is_sensitive_path(path) or (isinstance(rendered, str) and is_sensitive_string(rendered)) or (isinstance(live, str) and is_sensitive_string(live)):
            yield "DIFF path=" + (path or "<root>") + " kind=secret_value equality=no"
        else:
            yield "DIFF path=" + (path or "<root>") + " kind=value render=" + safe_value(path, rendered) + " live=" + safe_value(path, live)


def summarize_xray(value: Any) -> dict[str, Any]:
    inbounds = value.get("inbounds", []) if isinstance(value, dict) else []
    outbounds = value.get("outbounds", []) if isinstance(value, dict) else []
    clients = []
    if isinstance(inbounds, list):
        for inbound in inbounds:
            if not isinstance(inbound, dict):
                continue
            settings = inbound.get("settings", {})
            if not isinstance(settings, dict):
                continue
            inbound_clients = settings.get("clients", [])
            if isinstance(inbound_clients, list):
                clients.extend(inbound_clients)
    return {
        "inbound_count": len(inbounds) if isinstance(inbounds, list) else "error",
        "outbound_count": len(outbounds) if isinstance(outbounds, list) else "error",
        "client_count": len(clients),
        "outbound_protocols": sorted([str(item.get("protocol", "")) for item in outbounds if isinstance(item, dict)]),
        "listener_ports": sorted([str(item.get("port", "")) for item in inbounds if isinstance(item, dict)]),
        "protocol_security_network": sorted([
            str(item.get("protocol", "")) + "/" + str((item.get("streamSettings", {}) or {}).get("security", "")) + "/" + str((item.get("streamSettings", {}) or {}).get("network", ""))
            for item in inbounds
            if isinstance(item, dict)
        ]),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Read-only Xray structural diff without secrets")
    parser.add_argument("--rendered", default=".render/xray/config.json")
    parser.add_argument("--live", default="/usr/local/etc/xray/config.json")
    args = parser.parse_args()

    print("XRAY_STRUCTURAL_DIFF_DIAGNOSTIC=started")
    print("rendered_path_exists=" + ("yes" if os.path.exists(args.rendered) else "no"))
    print("live_path_exists=" + ("yes" if os.path.exists(args.live) else "no"))

    if not os.path.exists(args.rendered) or not os.path.exists(args.live):
        print("XRAY_STRUCTURAL_EQUIVALENT=no")
        print("DONE: read-only xray structural diagnostic completed")
        return 2

    rendered = load_json(args.rendered)
    live = load_json(args.live)
    print("rendered/live sha256 first8=" + sha8_file(args.rendered) + "/" + sha8_file(args.live))

    rendered_summary = summarize_xray(rendered)
    live_summary = summarize_xray(live)
    for key in ["inbound_count", "outbound_count", "client_count"]:
        print(key + " render/live=" + str(rendered_summary[key]) + "/" + str(live_summary[key]))
    for key in ["outbound_protocols", "listener_ports", "protocol_security_network"]:
        print(key + " equality=" + ("yes" if rendered_summary[key] == live_summary[key] else "no"))

    rendered_redacted = canonical_redacted(rendered)
    live_redacted = canonical_redacted(live)
    rendered_hash = sha8_bytes(canonical_json(rendered_redacted))
    live_hash = sha8_bytes(canonical_json(live_redacted))
    print("redacted_normalized_hash first8 render/live=" + rendered_hash + "/" + live_hash)

    diffs = list(diff_values(rendered_redacted, live_redacted))
    if diffs:
        print("XRAY_STRUCTURAL_DIFF_COUNT=" + str(len(diffs)))
        for line in diffs[:200]:
            print(line)
        if len(diffs) > 200:
            print("DIFF_TRUNCATED=yes total=" + str(len(diffs)))
    else:
        print("XRAY_STRUCTURAL_DIFF_COUNT=0")

    equivalent = rendered_hash == live_hash and not diffs
    print("XRAY_STRUCTURAL_EQUIVALENT=" + ("yes" if equivalent else "no"))
    print("DONE: read-only xray structural diagnostic completed")
    return 0 if equivalent else 1


if __name__ == "__main__":
    sys.exit(main())
