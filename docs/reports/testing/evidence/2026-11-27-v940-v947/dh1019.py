# 测试 v9.43（PR #1019）：比对改动前后 data/authoring 里所有改了的数，按 新/旧 比值分组，挑出不是 ×1.2 / ×1.8 的
import json, subprocess, sys, collections
A, B = sys.argv[1], sys.argv[2]
files = subprocess.check_output(["git", "diff", "--name-only", A, B, "--", "data/authoring"]).decode().split()
def load(rev, f):
    try: return json.loads(subprocess.check_output(["git", "show", f"{rev}:{f}"], stderr=subprocess.DEVNULL))
    except Exception: return None
rows = []
def walk(o, n, path, f):
    if isinstance(o, dict) and isinstance(n, dict):
        for k in o:
            if k in n: walk(o[k], n[k], path + "." + k, f)
    elif isinstance(o, list) and isinstance(n, list) and len(o) == len(n):
        for i, (x, y) in enumerate(zip(o, n)): walk(x, y, path + f"[{i}]", f)
    elif isinstance(o, (int, float)) and isinstance(n, (int, float)) and not isinstance(o, bool) and o != n:
        rows.append((f.split("/")[-2] + "/" + f.split("/")[-1][:-5], path, o, n, n / o if o else None))
for f in files:
    if not f.endswith(".json"): continue
    o, n = load(A, f), load(B, f)
    if o is None or n is None: continue
    walk(o, n, "", f)
buckets = collections.Counter()
odd = []
for r in rows:
    q = r[4]
    if q is None: odd.append(r); continue
    exp = None
    for e in (1.2, 1.8):
        # 取整的容差：整数时 |新 - 旧×e| <= 0.5
        if abs(r[3] - r[2] * e) <= 0.5 + 1e-6 or abs(q - e) < 0.02: exp = e
    buckets[exp] += 1
    if exp is None: odd.append(r)
print("DH1019 改了的数 %d 个；×1.2 %d，×1.8 %d，其它 %d" % (len(rows), buckets[1.2], buckets[1.8], len(odd)))
for r in odd: print("DH1019 其它：%s %s %s → %s（×%s）" % (r[0], r[1], r[2], r[3], ("%.2f" % r[4]) if r[4] else "-"))
