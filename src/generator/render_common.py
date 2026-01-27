import json
import os
from dataclasses import dataclass
from typing import Any, Dict, List, Optional


@dataclass(frozen=True)
class User:
    tg_id: str
    uuid: str
    status: str
    sub_token: Optional[str]


def _as_str(v: Any) -> str:
    if v is None:
        return ""
    return str(v).strip()


def _pick(d: Dict[str, Any], keys: List[str]) -> str:
    for k in keys:
        if k in d and d[k] is not None:
            s = _as_str(d[k])
            if s:
                return s
    return ""


def load_users_json(path: str) -> Dict[str, Any]:
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def parse_users(doc: Dict[str, Any]) -> List[User]:
    arr = []
    if isinstance(doc.get("users"), list):
        arr = doc["users"]
    elif isinstance(doc.get("whitelist"), list):
        arr = doc["whitelist"]

    out: List[User] = []
    for raw in arr:
        if not isinstance(raw, dict):
            continue

        tg_id = _pick(raw, ["tg_id", "telegram_id", "id"])
        uuid = _pick(raw, ["uuid", "vless_uuid", "client_uuid"])
        status = _pick(raw, ["status"]) or "active"
        sub_token = _pick(raw, ["sub_token", "token", "sub_id", "sub_file"]) or None

        if not tg_id or not uuid:
            continue

        out.append(User(tg_id=tg_id, uuid=uuid, status=status, sub_token=sub_token))

    return out


def filter_active(users: List[User]) -> List[User]:
    return [u for u in users if u.status.lower() == "active"]


def ensure_dir(path: str) -> None:
    os.makedirs(path, exist_ok=True)


def write_text(path: str, content: str) -> None:
    d = os.path.dirname(path)
    if d:
        ensure_dir(d)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(content)


def write_json(path: str, obj: Any) -> None:
    d = os.path.dirname(path)
    if d:
        ensure_dir(d)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        json.dump(obj, f, ensure_ascii=False, indent=2, sort_keys=False)
        f.write("\n")


def require_env(name: str) -> str:
    v = os.environ.get(name)
    if v is None or not str(v).strip():
        raise SystemExit(f"missing required env: {name}")
    return str(v).strip()


def split_csv(v: Optional[str]) -> List[str]:
    if not v:
        return []
    items = [x.strip() for x in str(v).split(",")]
    return [x for x in items if x]
