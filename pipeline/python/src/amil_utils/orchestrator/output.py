"""JSON output helpers matching CJS amil-tools output format."""
from __future__ import annotations

import json
import os
import sys
import tempfile
import time

# Large payload threshold — matches CJS constant (Claude Code Bash tool ~50KB buffer)
_LARGE_PAYLOAD_THRESHOLD = 50_000


def output(data: dict, raw: bool = False, raw_value: str | None = None) -> None:
    """Print JSON result. Match CJS output() exactly.

    Behavior matches core.cjs output(result, raw, rawValue):
    1. If raw=True and raw_value is provided, write raw_value as-is.
    2. Otherwise, JSON-encode data and write to stdout.
    3. If JSON exceeds 50KB, write to temp file and emit '@file:<path>'.
    4. Exit with code 0 after writing.
    """
    if raw and raw_value is not None:
        sys.stdout.write(str(raw_value))
    else:
        encoded = json.dumps(data, indent=2)
        if len(encoded) > _LARGE_PAYLOAD_THRESHOLD:
            tmp_path = os.path.join(
                tempfile.gettempdir(),
                f"amil-{int(time.time() * 1000)}-{os.getpid()}.json",
            )
            fd = os.open(tmp_path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
            try:
                with os.fdopen(fd, "w", encoding="utf-8") as f:
                    f.write(encoded)
            except Exception:
                os.close(fd)
                raise
            sys.stdout.write(f"@file:{tmp_path}")
        else:
            sys.stdout.write(encoded)
    sys.exit(0)


def error(message: str) -> None:
    """Print error to stderr and exit 1. Match CJS error() exactly."""
    sys.stderr.write(f"Error: {message}\n")
    sys.exit(1)
