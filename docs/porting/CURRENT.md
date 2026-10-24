# SMMneo: running and reviewing

This is a local SMW-focused development branch based on GodotWE `4a836e6`.
It adds native gameplay, editor/history and SWE preservation. It is not a
complete SMM:WE replacement or an online client, and upstream acceptance has
not been agreed. The detailed historical record remains in HANDOFF.md.

## Project boundaries (2026-10-25)

- SMMneo development: `C:/Working/SMMneo/GodotWE`, branch `SMMneo`.
- Focused GodotWE upstream contributions: the separate `C:/Working/GodotWE`
  repository, using its own feature branches.

The former `C:/Working/新建文件夹` workspace was renamed to
`C:/Working/SMMneo`. Historical records may still contain the former path.
Both projects continue independently. Useful changes can be adapted in either
direction after reviewing the receiving project's interfaces and behavior;
the large integration branch is not an upstream PR unit. The existing SMMneo
WorldPresentation and GodotWE native interpolation need separate integration
review. The source checkpoint is published on the `SMMneo` branch of
[MegaCeleste/SuperMarioMaker_neo](https://github.com/MegaCeleste/SuperMarioMaker_neo/tree/SMMneo).
The existing remote `main` and earlier branches are preserved. Local `origin`
points to this independent repository; `upstream` points to NCubss/GodotWE for
reviewing future updates. Publication does not select new gameplay scope.
Converted assets and locally generated slope-art templates stay excluded.

## Start here

- [Implementation guide in Chinese](IMPLEMENTATION-GUIDE.zh-CN.md): how each
  existing feature works, its code entry points and its limitations.
- [Structure review](STRUCTURE-REVIEW-2026-10-23.md): actual contribution gaps
  and suggested boundaries for an initial upstream patch.
- [Architecture](ARCHITECTURE.md): native module/data ownership.
- [Licensing and assets](LICENSING.md): base/new-code notices and local assets.

## Prepare and run

The tested local engine is Godot 4.7.2. Python 3 is used for preparation and test
tools. Converted OpenWE assets are ignored by Git; cloning code alone does not
provide them. Supply a local reference checkout matching reference.lock and
follow its asset/usage restrictions. Nothing below downloads or bundles art.

From the repository root:

```text
python -I tools/porting/prepare_slice.py <path-to-local-openwe-reference>
<path-to-godot-executable> --editor --path .
```

Open the configured main scene for the title/editor path. Key bindings live
in project.godot under input. This branch adds Space for Jump, Shift for Run
and Tab for Spin alongside the original mappings. The native editor Play
control enters test-play.

The full represented workflow should be verified on a clean prepared copy
before handing it to another developer. A successful run on this workstation
alone does not establish cross-machine or export compatibility.

## Verification

```text
python -I tools/porting/run_tests.py --import --godot <path-to-godot-executable>
python -I tools/porting/capture_slice.py --semisolid --fps 60
python -I tools/porting/capture_slice.py --semisolid --fps 120
```

Headless tests check 57 native scenes, plus import and sprite metadata guards.
Actual-render checks are separate and feature-specific. Logs/screenshots stay
under ignored `.godot/porting-tests/`; exit resource diagnostics retained there
must not be described as an absence of all leaks.

The first style batch covers seven explicitly listed files, not all existing
scripts. To install the optional development tool in a workspace-local target:

```text
python -I -m pip install --target ../.tools/gdtoolkit -r tools/porting/requirements-style.txt
python -I tools/porting/check_style.py
python -I tools/porting/check_style.py --all
```

The first check enforces formatting, lint and public-member documentation on
the reviewed batch. `--all` deliberately reports the remaining runtime backlog
and may fail. Do not present the seven-file result as whole-project compliance.

## Scope and review boundaries

Current features include SMW movement/powers/swimming, the documented enemy
subset, native palette/history/contents, terrain and slopes, six course themes,
ordinary springs/platforms, SWE subset round-tripping and display improvements.
The Chinese implementation guide itemizes them and identifies incomplete parts.

Other styles, complete object/attachment combinations, door/pipe area travel,
all course systems, original-binary save compatibility and online integration
remain incomplete. Slopes use explicit project-extension SWE IDs.

Candidate first discussion: the EditorPlayer unbound-context startup fix.
It needs an independent minimal reproduction and extraction from this large
integration branch; the existing startup test depends on other branch changes.
