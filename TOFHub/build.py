#!/usr/bin/env python3
"""Gabungkan semua modul TOFHub/ jadi SATU file: TOFHub_bundle.lua
Pakai:  python3 build.py            (jalankan di dalam folder TOFHub/)
Tiap modul dibungkus function(...) sehingga `local Hub = ...` tetap bekerja.
"""
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent
OUT = ROOT.parent / "TOFHub_bundle.lua" if ROOT.name == "TOFHub" else ROOT / "TOFHub_bundle.lua"

mods = []
for f in sorted(ROOT.rglob("*.lua")):
    rel = f.relative_to(ROOT).as_posix()
    if rel == "main.lua" or rel.startswith("tools/"):
        continue  # tools/ = skrip mandiri (bukan modul hub)
    mods.append((rel[:-4], f.read_text(encoding="utf-8")))

parts = ["{"]
for name, src in mods:
    parts.append('["%s"] = function(...)\n%s\nend,' % (name, src.rstrip()))
parts.append("}")
bundle_tbl = "\n".join(parts)

main = (ROOT / "main.lua").read_text(encoding="utf-8")
import re
# ganti SELURUH baris marker (termasuk komentar di ujungnya) dengan tabel bundle
pattern = re.compile(r"^local BUNDLE -- @bundle[^\n]*$", re.M)
assert pattern.search(main), "marker bundle tidak ditemukan di main.lua"
main = pattern.sub(lambda m: "local BUNDLE = " + bundle_tbl, main, count=1)
OUT.write_text(main, encoding="utf-8")
print("OK ->", OUT, "(%d modul, %d baris)" % (len(mods), main.count("\n")))
