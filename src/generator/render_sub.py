#!/usr/bin/env python3
import argparse
import os
from typing import List, Optional

from render_common import (
    ensure_dir,
    filter_active,
    load_users_json,
    parse_users,
    require_env,
    split_csv,
    write_text,
)


def _vless_uri(
    uuid: str,
    host: str,
    port: str,
    sni: str,
    pbk: str,
    sid: str,
    fp: str,
    path: str,
    tag: str,
) -> str:
    qp = (
        f"type=tcp"
        f"&security=reality"
        f"&sni={sni}"
        f"&pbk={pbk}"
        f"&sid={sid}"
        f"&fp={fp}"
        f"&spx={path}"
        f"&flow=xtls-rprx-vision"
        f"&encryption=none"
    )
    return f"vless://{uuid}@{host}:{port}?{qp}#{tag}"


def build_lines_for_user(
    uuid: str,
    host: str,
    port: str,
    sni: str,
    pbk: str,
    sid: str,
    fp: str,
    paths: List[str],
    tag: str,
) -> str:
    if not paths:
        paths = ["/"]

    lines: List[str] = []
    for p in paths:
        if not p.startswith("/"):
            p = "/" + p
        lines.append(_vless_uri(uuid, host, port, sni, pbk, sid, fp, p, tag))
    return "\n".join(lines) + "\n"


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--users", required=True, help="path to SoT users.json")
    ap.add_argument("--out_dir", required=True, help="output directory for subscription .txt files")
    args = ap.parse_args()

    host = require_env("VPS_SUB_HOST")
    port = require_env("VPS_VLESS_PORT")
    sni = require_env("VPS_REALITY_SNI")
    pbk = require_env("VPS_REALITY_PBK")
    sid = require_env("VPS_REALITY_SID")
    fp = require_env("VPS_REALITY_FP")
    paths = split_csv(os.environ.get("VPS_REALITY_PATHS"))

    doc = load_users_json(args.users)
    users = filter_active(parse_users(doc))

    ensure_dir(args.out_dir)

    for u in users:
        key: Optional[str] = u.sub_token or u.tg_id
        key = str(key).strip()
        if not key:
            continue

        body = build_lines_for_user(
            uuid=u.uuid,
            host=host,
            port=port,
            sni=sni,
            pbk=pbk,
            sid=sid,
            fp=fp,
            paths=paths,
            tag=f"tg:{u.tg_id}",
        )
        out_path = os.path.join(args.out_dir, f"{key}.txt")
        write_text(out_path, body)


if __name__ == "__main__":
    main()
