#!/usr/bin/env python3
"""AzooKeyKanaKanjiConverter の CLI (anco) を使って、辞書・エンジンのバージョン間で変換精度を比べる。

使い方: python3 eval/compare_cli.py <corpus.tsv> <name>=<path/to/CliTool> [...]
予測変換を無効にし、入力全体を変換した候補（完全一致変換）だけで評価する。
"""
import subprocess
import sys
from collections import defaultdict


def load(path):
    rows = []
    for line in open(path, encoding="utf-8"):
        if not line.strip() or line.startswith("#"):
            continue
        reading, answers, category = line.rstrip("\n").split("\t")
        rows.append((reading, answers.split("|"), category))
    return rows


def run(cli, reading):
    # 予測の無効化オプションはバージョンで名前が異なる（v0.11系: --disable_prediction）
    for flags in (["--prediction_mode", "disabled"], ["--disable_prediction"]):
        result = subprocess.run(
            [cli, "run", "-n", "10", "--only_whole_conversion", *flags, reading],
            capture_output=True, text=True, check=False,
        )
        if "Unknown option" not in result.stderr + result.stdout:
            break
    out = result.stdout
    lines = [l for l in out.splitlines() if l and not l.startswith("\x1b") and "Entropy" not in l]
    return lines[:10]


def main():
    corpus = load(sys.argv[1])
    clis = [a.split("=", 1) for a in sys.argv[2:]]
    for name, cli in clis:
        stats = defaultdict(lambda: [0, 0, 0, 0])
        misses = []
        for reading, answers, category in corpus:
            cands = run(cli, reading)
            rank = next((i for i, c in enumerate(cands) if c in answers), None)
            for key in (category, "ALL"):
                s = stats[key]
                s[0] += 1
                if rank is not None and rank == 0:
                    s[1] += 1
                if rank is not None and rank < 3:
                    s[2] += 1
                if rank is not None:
                    s[3] += 1
            if rank != 0:
                misses.append((category, reading, answers[0], cands[:3]))
        print(f"## {name}")
        print("| category | n | top1 | top3 | top10 |")
        print("|---|---|---|---|---|")
        for key in sorted(stats, key=lambda k: (k == "ALL", k)):
            n, t1, t3, t10 = stats[key]
            print(f"| {key} | {n} | {t1/n:.0%} | {t3/n:.0%} | {t10/n:.0%} |")
        print()
        print("<details><summary>1位で正解しなかった例</summary>\n")
        for category, reading, answer, cands in misses:
            print(f"- [{category}] {reading} → 期待: {answer} / 結果: {' , '.join(cands)}")
        print("\n</details>\n")


if __name__ == "__main__":
    main()
