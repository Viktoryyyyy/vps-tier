#!/usr/bin/env python3
import argparse
from typing import Any, Dict, List

from render_common import filter_active, load_users_json, parse_users, write_json


def build_clients(users_json_path: str) -> List[Dict[str, Any]]:
    doc = load_users_json(users_json_path)
    users = filter_active(parse_users(doc))
    out: List[Dict[str, Any]] = []
    for u in users:
        out.append(
            {
                "id": u.uuid,
                "email": f"tg:{u.tg_id}",
            }
        )
    return out


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--users", required=True, help="path to SoT users.json")
    ap.add_argument("--out", required=True, help="output json file (clients block)")
    args = ap.parse_args()

    write_json(args.out, {"clients": build_clients(args.users)})


if __name__ == "__main__":
    main()
