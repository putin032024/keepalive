#!/usr/bin/env python3
"""List files + sizes inside a .deb (for CI logs)."""
import lzma, sys, subprocess, tempfile, tarfile
from pathlib import Path

deb = Path(sys.argv[1]).resolve()
td = Path(tempfile.mkdtemp())
subprocess.check_call(["ar", "x", str(deb)], cwd=td)
data = next(td.glob("data.tar*"))
name = data.name
if name.endswith(".lzma"):
    f = lzma.open(data)
    t = tarfile.open(fileobj=f)
elif name.endswith(".gz"):
    t = tarfile.open(data, "r:gz")
else:
    t = tarfile.open(data)
print("=== DATA FILES ===")
total = 0
for m in t.getmembers():
    if m.isfile():
        print("%8d  %s" % (m.size, m.name))
        total += m.size
print("TOTAL_UNCOMPRESSED=%d" % total)
t.close()
