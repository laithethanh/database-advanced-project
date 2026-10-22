import getpass
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def load_env():
    for path in (ROOT / ".env", Path.cwd() / ".env"):
        if not path.is_file():
            continue
        for raw_line in path.read_text(encoding="utf-8-sig").splitlines():
            line = raw_line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            if line.startswith("export "):
                line = line[7:].lstrip()
            key, value = line.split("=", 1)
            key = key.strip()
            value = value.strip().strip('"').strip("'")
            if key:
                os.environ.setdefault(key, value)


def db_params(database=None):
    load_env()
    return {
        "host": os.environ.get("DB_HOST", "127.0.0.1"),
        "port": int(os.environ.get("DB_PORT", "3306")),
        "user": os.environ.get("DB_USER", "root"),
        "password": os.environ.get("DB_PASSWORD") or getpass.getpass("Mat khau MySQL: "),
        "database": database or os.environ.get("DB_NAME", "ecommerce_advanced"),
        "charset": "utf8mb4",
    }
