#!/usr/bin/env python3
"""Syntax check for every .luau file (tree-sitter-luau). Catches typos like a bad type annotation.
Install once: pip install tree-sitter tree-sitter-language-pack. Does NOT check types or runtime errors."""
import sys, pathlib
from tree_sitter_language_pack import get_parser
parser = get_parser('luau')
bad = 0
def errs(n, out):
    if n.type == 'ERROR' or n.is_missing:
        out.append(n.start_point)
    for c in n.children:
        errs(c, out)
root = pathlib.Path(__file__).resolve().parent.parent
for f in sorted(list(root.glob('src/**/*.luau')) + list(root.glob('tests/*.luau'))):
    out = []
    errs(parser.parse(f.read_bytes()).root_node, out)
    if out:
        bad += 1
        print(f"{f.relative_to(root)}: syntax error near line {out[0][0] + 1}")
print("syntax OK" if not bad else f"{bad} file(s) with errors")
sys.exit(1 if bad else 0)
