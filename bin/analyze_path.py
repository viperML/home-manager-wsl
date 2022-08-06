#!/usr/bin/env python3
import os
import sys
from pathlib import Path

"""
Small script that compares the binaries provided by the base distribution,
to the binaries provided by the home-manager profile.
"""

FHS_PATH = [
    "/bin",
    "/usr/bin",
    "/sbin",
    "/usr/sbin",
]

FHS_PATH = [Path(x) if Path(x).exists() else None for x in FHS_PATH]

fhs_programs = set()
for path in FHS_PATH:
    fhs_programs = fhs_programs | {b.name for b in path.glob("*")}

PROFILE_PATH = Path(f"/nix/var/nix/profiles/per-user/{os.environ['USER']}/profile/bin")

nix_programs = {p.name for p in PROFILE_PATH.glob("*")}

only_in_fhs = sorted(fhs_programs - nix_programs)

print("Binaries not in nix profile:", file=sys.stderr)
for command in only_in_fhs:
    print(command)
