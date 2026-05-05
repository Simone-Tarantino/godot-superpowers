---
name: setup-git-godot
description: Set up Git for a Godot 4.x project — `.gitignore` for engine cache and exports, `.gitattributes` with Git LFS for binary assets (PNG, WAV, OGG, MP3, FBX, GLB, BLEND, ZIP, large `.tres`), `.gdignore` for asset-only folders, and the one-time LFS init. Use for any new Godot project, or to repair a project that committed `.godot/` or large binaries to git history.
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# setup-git-godot

Configure git correctly for a Godot 4.x project. Two failure modes this skill prevents:

1. **Committed engine cache** — `.godot/` and `.import/` are regenerated on every editor open, contain absolute paths, and bloat history. Never commit them.
2. **Binary assets in regular git** — audio, textures, 3D meshes, and large `.tres` files balloon `.git/` past usable size and make `git clone` painful. Track them with **Git LFS** instead.

Both fixes are one-shot: ship the configs once, the project stays clean.

## What this skill produces

| File | Purpose |
|------|---------|
| `.gitignore` | Excludes `.godot/`, `.import/`, exports, `*.translation`, OS junk |
| `.gitattributes` | Routes binary asset extensions through Git LFS, marks text files as `text=auto` |
| `addons/.gdignore` (optional) | Tells the Godot importer to skip a folder. Useful for vendored sources you keep in-repo but do not want imported. |

It also walks the user through the one-time `git lfs install` setup and verifies the result with a tracked-list dump.

## `.gitignore` (canonical for Godot 4.3+)

Reference: [Godot project file structure → exporting](https://docs.godotengine.org/en/stable/tutorials/best_practices/project_organization.html). The exhaustive ignore list:

```gitignore
# Godot 4+ engine cache (auto-regenerated on editor open — never commit)
.godot/
.import/

# Export output
builds/
exports/
*.pck
*.zip
*.apk
*.aab
*.exe
*.dmg
*.app
*.x86_64
*.x86_32

# Translations are generated from .csv/.po sources — keep sources, drop generated
*.translation

# Editor / OS junk
.DS_Store
Thumbs.db
*.swp
*.swo
*~

# Local IDE configs
.vscode/
.idea/
*.iml

# Local-only Claude state
.claude/settings.local.json
```

**Do NOT ignore**:
- `project.godot` — the project manifest.
- `*.import` files at the asset level — these are tiny per-asset import settings and MUST be committed alongside the asset (otherwise the importer regenerates with default settings, losing per-asset overrides).
- `.tscn`, `.tres`, `.gd`, `.gdshader` — text files, version-control normally.
- `export_presets.cfg` — keep, but scrub credentials before committing (see the `export-config` skill for the credentials-via-env pattern).

## `.gitattributes` (Git LFS routing)

Reference: [Git LFS docs](https://git-lfs.com/). Without LFS, a 50 MB FBX in commit history stays in every clone forever. With LFS, only a pointer goes to the repo; the blob lives in LFS storage and is fetched on demand.

```gitattributes
# Normalize line endings on text — keeps Windows / macOS / Linux diffs sane
* text=auto eol=lf

# Source files: explicit text
*.gd        text eol=lf
*.gdshader  text eol=lf
*.tscn      text eol=lf
*.tres      text eol=lf
*.cfg       text eol=lf
*.import    text eol=lf
*.csv       text eol=lf
*.json      text eol=lf
*.md        text eol=lf

# Audio → LFS
*.wav  filter=lfs diff=lfs merge=lfs -text
*.ogg  filter=lfs diff=lfs merge=lfs -text
*.mp3  filter=lfs diff=lfs merge=lfs -text
*.flac filter=lfs diff=lfs merge=lfs -text

# Textures / images → LFS (PNG/JPG ship in most Godot projects; SVG stays text)
*.png  filter=lfs diff=lfs merge=lfs -text
*.jpg  filter=lfs diff=lfs merge=lfs -text
*.jpeg filter=lfs diff=lfs merge=lfs -text
*.webp filter=lfs diff=lfs merge=lfs -text
*.exr  filter=lfs diff=lfs merge=lfs -text
*.hdr  filter=lfs diff=lfs merge=lfs -text
*.tga  filter=lfs diff=lfs merge=lfs -text
*.psd  filter=lfs diff=lfs merge=lfs -text

# 3D meshes / scenes → LFS
*.fbx   filter=lfs diff=lfs merge=lfs -text
*.glb   filter=lfs diff=lfs merge=lfs -text
*.gltf  filter=lfs diff=lfs merge=lfs -text
*.blend filter=lfs diff=lfs merge=lfs -text
*.obj   filter=lfs diff=lfs merge=lfs -text

# Fonts → LFS
*.ttf filter=lfs diff=lfs merge=lfs -text
*.otf filter=lfs diff=lfs merge=lfs -text

# Video (cutscenes etc) → LFS
*.ogv  filter=lfs diff=lfs merge=lfs -text
*.webm filter=lfs diff=lfs merge=lfs -text
*.mp4  filter=lfs diff=lfs merge=lfs -text

# Archives → LFS
*.zip filter=lfs diff=lfs merge=lfs -text
*.7z  filter=lfs diff=lfs merge=lfs -text
*.tar.gz filter=lfs diff=lfs merge=lfs -text
```

Tweak the list to match the project's actual asset palette — a 2D pixel-art project does not need FBX/GLB/BLEND lines, a code-only prototype needs none of it.

## Workflow

```bash
# 1. Install LFS once per developer machine (idempotent)
git lfs install

# 2. Drop the configs in
# (after writing .gitignore + .gitattributes from the templates above)

# 3. If the repo already exists with binaries committed BEFORE LFS:
#    a) configs alone do not migrate history — they only affect future commits.
#    b) for new commits, `git add` will route matching extensions through LFS automatically.
#    c) to migrate existing history, see the "Migrating an existing repo" section.

# 4. Verify LFS routing on a sample asset
git check-attr filter -- assets/sfx/jump.wav
# expected: assets/sfx/jump.wav: filter: lfs

# 5. Commit
git add .gitignore .gitattributes
git commit -m "chore: configure git for Godot project (ignore engine cache, LFS for binaries)"
```

## Migrating an existing repo

If the project already has `.godot/` or binaries in history, `.gitignore` does not retroactively remove them — they stay in past commits and inflate `.git/` forever. Two options:

1. **Untrack only (safe, history stays bloated)**:
   ```bash
   git rm -r --cached .godot .import
   git commit -m "chore: stop tracking Godot engine cache"
   ```
   Future commits stay clean; history remains as-is.

2. **Rewrite history (destructive — coordinate with the team)**:
   Use [`git filter-repo`](https://github.com/newren/git-filter-repo) (NOT `filter-branch`):
   ```bash
   git filter-repo --path .godot --invert-paths
   git filter-repo --path .import --invert-paths
   ```
   Force-push afterwards. Every collaborator must re-clone.

For binaries already in history, run `git lfs migrate import --include="*.png,*.wav,*.fbx"` after configuring `.gitattributes`. Same caveat: rewrites history, requires team coordination, force-push needed.

## Hosting requirements

- **GitHub**: free LFS quota is 1 GB storage + 1 GB monthly bandwidth per account. Past that, paid data packs.
- **GitLab**: 10 GB per project on free tier, more on paid.
- **Self-hosted**: any Git LFS server (e.g. [`giftless`](https://github.com/datopian/giftless), built-in for Gitea/Forgejo).

If LFS quota is a problem and the team is small, `git-annex` is the alternative, but its workflow is more involved and the Godot importer does not care either way.

## Verification checklist

After running this skill, confirm:

- [ ] `.gitignore` contains `.godot/` and `.import/`.
- [ ] `git status` does not list `.godot/` or `.import/` as untracked or modified.
- [ ] `git lfs ls-files` returns the binary asset list (or empty if none yet exist).
- [ ] `git check-attr filter -- <some-binary>` reports `filter: lfs` for binaries, nothing for text.
- [ ] `project.godot` is tracked.
- [ ] Per-asset `.import` files are tracked (run `git ls-files | grep '\.import$' | head` to confirm).

## When NOT to use this skill

- Code-only research repos with no binary assets and no plan to ship — LFS is overhead with no benefit.
- Submodule projects where the parent repo already configures LFS — duplicating `.gitattributes` is fine but redundant.
- During a `gdscript-migrator` 3.x → 4.x port — the migration agent owns the move; run this skill after the port lands so the new file layout is what gets indexed.

## Related skills

- [`bootstrap-godot-project`](../bootstrap-godot-project/SKILL.md) — full directory + autoload scaffold; pair with this skill to land a clean repo on day one.
- [`export-config`](../export-config/SKILL.md) — keep `export_presets.cfg` tracked but route signing credentials through env vars instead of committing them.
