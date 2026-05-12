import os
import re
import sys

src = sys.argv[1]
dst = sys.argv[2]

with open(src, "r", encoding="utf-8") as f:
    data = f.read()

def repl(match):
    key = match.group(1)
    value = os.environ.get(key)
    if value is None:
        return match.group(0)
    return value

data = re.sub(r"\{\{([A-Z0-9_]+)\}\}", repl, data)

with open(dst, "w", encoding="utf-8") as f:
    f.write(data)
