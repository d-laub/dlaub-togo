# Statusline: jj/git worktree clarity — design

## Problem

`statusline-command.sh` renders the VCS segment of the Claude Code statusline. Two
cases render misleadingly:

1. **Linked git worktrees show stale jj info.** Inside a `git worktree` of a repo
   whose main checkout is colocated jj+git (e.g. `genoray/.claude/worktrees/svar2-conversion-fields`),
   `git branch --show-current` correctly returns the worktree branch
   (`worktree-svar2-conversion-fields`). But `jj root --ignore-working-copy` walks
   *up* out of the linked worktree into the parent (`genoray/`) and succeeds, so the
   jj branch wins and prints the **parent** repo's bookmarks:

   ```
   [Opus 4.8] 📁 svar2-conversion-fields | 🌿 main main@origin svar-2 svar-2@origin
   ```

   None of that describes the worktree. It should read:

   ```
   [Opus 4.8] 📁 svar2-conversion-fields | 🌿 worktree-svar2-conversion-fields
   ```

2. **jj bookmark display is noisy and reads like a git/jj mashup.** In a real jj repo
   (e.g. `aster/`) the `bookmarks` template includes remote-tracking bookmarks, so a
   single `main` bookmark renders as `main main@origin`:

   ```
   [Opus 4.8] 📁 aster | 🌿 main main@origin
   ```

   It is all jj info, but the `@origin` half is noise, and there is no visual cue that
   this is jj rather than git. Also, `aster`'s working copy `@` is an empty new change
   sitting *ahead* of `main` (change `rxtlrzyr`); a bookmark-only display hides the
   actual workstream (the current change).

## Root causes

- **(1)** `jj root` resolves ancestors, so a linked git worktree nested under a
  colocated jj repo is mis-detected as jj. jj has no knowledge of the git worktree's
  branch (the worktree is not a jj workspace), so the info it prints is the parent's.
- **(2)** The `bookmarks` template includes remote-tracking bookmarks; `local_bookmarks`
  (verified available in jj 0.41) returns just `main`. No distinct icon for jj.

## Design

Rewrite only the VCS block (lines 22–32) of `statusline-command.sh`. Model, dir,
context bar, and timer are untouched. New precedence:

1. **Linked git worktree → git.** Detect via `git rev-parse --git-dir` containing
   `/worktrees/` (equivalently `--git-dir` ≠ `--git-common-dir`). When true, use
   `git branch --show-current` with the 🌿 icon and skip jj entirely.
2. **jj repo → jj label.** Icon 🥢 (distinct from git's 🌿). Label from
   `local_bookmarks` (no `@origin` noise), change-aware:
   - `@` sits exactly on a local bookmark → the bookmark, e.g. `🥢 main`
   - `@` is ahead of the nearest ancestor bookmark → `<bookmark>@<change-id>`,
     e.g. `🥢 main@rxtlrzyr`
   - no ancestor bookmark → just the change id, e.g. `🥢 rxtlrzyr`
3. **git repo → git branch.** 🌿 with `git branch --show-current`.
4. **neither → empty** (no VCS segment).

`--ignore-working-copy` is retained on every `jj` invocation so the frequent
statusline render stays read-only (no snapshot/mutation).

### Expected outputs

| Location | Before | After |
|---|---|---|
| `genoray/.claude/worktrees/svar2-conversion-fields` | `🌿 main main@origin svar-2 svar-2@origin` | `🌿 worktree-svar2-conversion-fields` |
| `aster/` (empty change on main) | `🌿 main main@origin` | `🥢 main@rxtlrzyr` |
| jj repo, `@` on a bookmark | — | `🥢 main` |
| jj repo, no ancestor bookmark | — | `🥢 rxtlrzyr` |
| plain git repo | `🌿 <branch>` | `🌿 <branch>` (unchanged) |

## jj template details

- Nearest ancestor local bookmark:
  `jj log --no-graph --ignore-working-copy -r 'heads(::@ & bookmarks())' -T local_bookmarks`
  (take first line).
- Local bookmark(s) exactly on `@`:
  `jj log --no-graph --ignore-working-copy -r @ -T local_bookmarks`.
- Short change id at `@`:
  `jj log --no-graph --ignore-working-copy -r @ -T 'change_id.shortest(8)'`.

Decision logic: if `@` has a local bookmark, show it. Else compute nearest ancestor
bookmark + change id: if a nearest bookmark exists, show `<bookmark>@<changeid>`,
otherwise show `<changeid>`.

## Scope / non-goals

- Only the VCS block changes; the rest of the script is untouched.
- Deployment (copying the tracked source to `~/.claude/statusline-command.sh`) remains
  a manual step; `update_claude.sh` still syncs only `CLAUDE.md`. Wiring the statusline
  into `update_claude.sh` is a possible follow-up, out of scope here.

## Testing

Manual verification against the three real repos (edit is to a live tracked script, no
unit-test harness exists for it):

- `genoray/.claude/worktrees/svar2-conversion-fields` → `🌿 worktree-svar2-conversion-fields`
- `aster/` → `🥢 main@rxtlrzyr`
- a plain git repo (e.g. `dlaub-togo`) → `🌿 <branch>` unchanged

Drive each by piping a minimal JSON payload (`{"model":...,"workspace":{"current_dir":...},...}`)
into the script from the target directory and asserting the first output line.
