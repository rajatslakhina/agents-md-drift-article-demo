#!/usr/bin/env python3
"""Aggregates docs/field-audit/raw/*.json (output of Tools/drift-audit) into summary.json."""
import glob, json, os, statistics, sys

root = sys.argv[1] if len(sys.argv) > 1 else "docs/field-audit"
repos = []
for path in sorted(glob.glob(os.path.join(root, "raw", "*.json"))):
    data = json.load(open(path))
    c = dict(name=os.path.basename(path)[:-5].replace("_", "/", 1), head=data["head"],
             instructionFiles=len(data["files"]), references=0, live=0,
             changedSinceWritten=0, fiveOrMore=0, removed=0, ignored=0, unresolved=0)
    for f in data["files"]:
        for r in f["references"]:
            c["references"] += 1
            s = r["status"]
            if s == "live":
                c["live"] += 1
                c["changedSinceWritten"] += r["commitsSinceWritten"] > 0
                c["fiveOrMore"] += r["commitsSinceWritten"] >= 5
            else:
                c[s] += 1
    repos.append(c)
keys = ["instructionFiles", "references", "live", "changedSinceWritten", "fiveOrMore", "removed", "ignored", "unresolved"]
total = {k: sum(r[k] for r in repos) for k in keys}
total["repos"] = len(repos)
total["changedShare"] = round(100 * total["changedSinceWritten"] / total["live"], 1)
total["fiveOrMoreShare"] = round(100 * total["fiveOrMore"] / total["live"], 1)
json.dump({"total": total, "repos": repos}, open(os.path.join(root, "summary.json"), "w"), indent=1)
print(json.dumps(total, indent=1))
for r in repos:
    print(r["name"].ljust(40), r["live"], r["changedSinceWritten"], r["removed"])
