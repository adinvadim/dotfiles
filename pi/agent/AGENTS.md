# Default project scouting

When the user asks to study, understand, scout, audit, or onboard into a project, start with classic scouting.

## Classic scouting workflow

1. Run `docs-list --root . --plain` early.
2. If `subagent` is available, prefer parallel recon:
   - `scout` for codebase structure, entry points, architecture, key files, tests, and configs.
   - `docs-scout` for docs inventory, `read_when` hints, setup/run/test/deploy docs, ADRs, and workflow notes.
3. Prefer modern fast tools and good analogs:
   - use `rg` instead of `grep` when searching text
   - use `find` or `fd`-style patterns for file discovery if available
   - use `docs-list` for docs inventory instead of ad-hoc scanning
4. Merge both into one compressed handoff:
   - project shape
   - important docs
   - entry points
   - commands to know
   - risks / unknowns
   - start-here files
5. If `docs-list` finds no docs, say so and continue with code scouting.
6. If `subagent` is unavailable, do the same workflow yourself: `docs-list` first, then code scan.

For docs work, prefer authoritative project docs over guessing. Read the specific docs you cite.

## Git workflow

For commit operations, prefer slash commands over ad-hoc shell commands:
- `/commit`
- `/commit-push`
- `/commit-push-pr`

Before every push, run reviewer first. `/commit-push` and `/commit-push-pr` should trigger `/review` automatically before committing/pushing.

Always use Conventional Commits format:
- `feat(scope): subject`
- `fix(scope): subject`
- `chore: subject`

After a successful commit via these commands, reset session added/removed line counters in the status footer.
Never push without a review pass first.
