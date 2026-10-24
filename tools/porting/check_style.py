"""Check the first reviewed GDScript batch without rewriting gameplay code.

Install requirements-style.txt into an isolated environment, or into the
workspace's .tools/gdtoolkit directory. --all reports the remaining runtime
documentation backlog; it is deliberately separate from the reviewed batch.
"""

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REVIEWED = (
    "scripts/level/parts/semisolid_part.gd",
    "scripts/level/entities/player_physics.gd",
    "scripts/level/entities/player_animation_rules.gd",
    "scripts/level/entities/player_swim_rules.gd",
    "scripts/level/actor_contacts.gd",
    "scripts/level/world_presentation.gd",
    "scripts/level/swe_level_serializer.gd",
)
DECLARATION = re.compile(
    r"^(?:@(?:export\w*|onready)(?:\([^\n]*\))?\s+)*"
    r"(?:static\s+)?(?:func|var|const|signal|enum)\s+([A-Za-z]\w*)"
)


def missing_documentation(path):
    """Report top-level public members without adjacent Godot ## documentation."""
    lines = path.read_text(encoding="utf-8-sig").splitlines()
    missing = []
    for index, line in enumerate(lines):
        match = DECLARATION.match(line)
        if match is None:
            continue
        previous = index - 1
        while previous >= 0 and lines[previous].startswith("@"):
            previous -= 1
        if previous < 0 or not lines[previous].startswith("##"):
            missing.append(f"{path.relative_to(ROOT)}:{index + 1}: {match[1]}")
    return missing


def main():
    arguments = argparse.ArgumentParser(description=__doc__)
    arguments.add_argument("--all", action="store_true", help="report all runtime scripts")
    args = arguments.parse_args()
    bundled = ROOT.parent / ".tools/gdtoolkit"
    if bundled.is_dir():
        sys.path.insert(0, str(bundled))
    try:
        from gdtoolkit.formatter import format_code, check_formatting_safety
        from gdtoolkit.linter import lint_code
    except ImportError:
        print("Install tools/porting/requirements-style.txt before running this check.")
        return 2
    files = sorted((ROOT / "scripts").rglob("*.gd")) if args.all else [ROOT / p for p in REVIEWED]
    errors = []
    for path in files:
        code = path.read_text(encoding="utf-8")
        try:
            formatted = format_code(code, max_line_length=100)
            check_formatting_safety(code, formatted, max_line_length=100)
            if code != formatted:
                errors.append(f"{path.relative_to(ROOT)}: formatting differs from gdformat")
            for problem in lint_code(code):
                errors.append(
                    f"{path.relative_to(ROOT)}:{problem.line}: "
                    f"{problem.description} ({problem.name})"
                )
        except Exception as error:
            errors.append(f"{path.relative_to(ROOT)}: formatter check failed: {error}")
        if path.read_bytes().startswith(b"\xef\xbb\xbf") or b"\r" in path.read_bytes():
            errors.append(f"{path.relative_to(ROOT)}: use UTF-8 without BOM and LF newlines")
        errors.extend(missing_documentation(path))
    for error in errors:
        print(error)
    scope = "all runtime scripts" if args.all else "reviewed batch only"
    print(f"{'FAIL' if errors else 'PASS'} style: {len(files)} files, {len(errors)} findings ({scope})")
    return int(bool(errors))


if __name__ == "__main__":
    raise SystemExit(main())
