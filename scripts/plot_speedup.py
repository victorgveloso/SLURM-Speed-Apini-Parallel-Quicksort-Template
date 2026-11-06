#!/usr/bin/env python3
"""Speedup plots for Requirement 4, from the CSV the programs print.

    python3 scripts/plot_speedup.py results/apini_<date>.csv [--out results/plots]

Input columns: version,p,nodes,n,seconds,ok   (rows with ok != 1 are ignored)
Repetitions are combined with the median. S(p, n) = T_sequential(n) / T_p(n).
Writes:
  summary.csv               version, n, p, T_p, T_seq, speedup, efficiency
  speedup_vs_p.png          one line per n, one panel per parallel version
  speedup_vs_n.png          one line per p, one panel per parallel version
summary.csv needs only the standard library; the plots need matplotlib
(pip install --user matplotlib).
"""
import argparse
import csv
import os
import statistics
import sys
from collections import defaultdict


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("csv")
    ap.add_argument("--out", default="results/plots")
    args = ap.parse_args()

    times = defaultdict(list)  # (version, n, p) -> [seconds]
    skipped = 0
    with open(args.csv, newline="") as f:
        for r in csv.DictReader(f):
            if r.get("version") in (None, "version"):
                continue
            if r["ok"] != "1":
                skipped += 1
                continue
            times[(r["version"], int(r["n"]), int(r["p"]))].append(float(r["seconds"]))
    if skipped:
        print(f"warning: ignored {skipped} row(s) with ok != 1", file=sys.stderr)
    med = {k: statistics.median(v) for k, v in times.items()}
    seq = {n: t for (v, n, p), t in med.items() if v == "sequential"}
    versions = sorted({v for (v, _, _) in med if v != "sequential"})
    if not seq:
        sys.exit("error: no 'sequential' rows; the speedup needs T_sequential(n)")

    os.makedirs(args.out, exist_ok=True)
    rows = []
    for v in versions:
        for (v2, n, p), t in sorted(med.items()):
            if v2 == v and n in seq:
                s = seq[n] / t
                rows.append([v, n, p, t, seq[n], s, s / p])
    path = os.path.join(args.out, "summary.csv")
    with open(path, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["version", "n", "p", "T_p", "T_seq", "speedup", "efficiency"])
        for r in rows:
            w.writerow([r[0], r[1], r[2], f"{r[3]:.6f}", f"{r[4]:.6f}", f"{r[5]:.3f}", f"{r[6]:.3f}"])
    print(f"wrote {path}")

    try:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
    except ImportError:
        print("matplotlib not installed: skipping the plots (pip install --user matplotlib)")
        return

    ns = sorted({r[1] for r in rows})
    ps = sorted({r[2] for r in rows})
    speed = {(r[0], r[1], r[2]): r[5] for r in rows}

    # Speedup as a function of the worker count, one line per input size.
    fig, axes = plt.subplots(1, len(versions), figsize=(6 * len(versions), 4.5), squeeze=False)
    for ax, v in zip(axes[0], versions):
        for n in ns:
            xs = [p for p in ps if (v, n, p) in speed]
            if xs:
                ax.plot(xs, [speed[(v, n, p)] for p in xs], marker="o", label=f"n = {n:,}")
        ax.plot([1, max(ps)], [1, max(ps)], "k--", linewidth=0.8, label="ideal")
        ax.set(title=f"{v}: speedup vs. workers", xlabel="workers p", ylabel="S = T_seq / T_p")
        ax.set_xticks(ps)
        ax.grid(alpha=0.3)
        ax.legend(fontsize=7)
    fig.tight_layout()
    fig.savefig(os.path.join(args.out, "speedup_vs_p.png"), dpi=150)
    print(f"wrote {os.path.join(args.out, 'speedup_vs_p.png')}")

    # Speedup as a function of the input size, one line per worker count.
    fig, axes = plt.subplots(1, len(versions), figsize=(6 * len(versions), 4.5), squeeze=False)
    for ax, v in zip(axes[0], versions):
        for p in ps:
            xs = [n for n in ns if (v, n, p) in speed]
            if xs:
                ax.plot(xs, [speed[(v, n, p)] for n in xs], marker="o", label=f"p = {p}")
        ax.set_xscale("log")
        ax.set(title=f"{v}: speedup vs. input size", xlabel="input size n", ylabel="S = T_seq / T_p")
        ax.grid(alpha=0.3)
        ax.legend(fontsize=7)
    fig.tight_layout()
    fig.savefig(os.path.join(args.out, "speedup_vs_n.png"), dpi=150)
    print(f"wrote {os.path.join(args.out, 'speedup_vs_n.png')}")


if __name__ == "__main__":
    main()
