# Trade-Tariff Worktree Isolation Hook – Rollout Plan

**Status**: Draft for socialisation
**Date**: 2026-05
**Owner**: William (with input from team)

---

## 1. Goal

Make long-path git worktrees (the pattern at `~/.config/superpowers/worktrees/...`) first-class citizens across the trade-tariff platform.

Developers should be able to:

- Create a worktree
- `cd` into it
- `direnv allow`
- Immediately have a working environment (Postgres on a short socket, Bundler/Yarn isolated, DB ready, pre-commit hooks installed, tests runnable)

---

## 2. Core Technical Pattern

### 2.1 Common to All Repos

- Worktree detection via `git rev-parse --git-dir` vs `--git-common-dir`
- Short paths for:
  - Bundler (`GEM_HOME`, `BUNDLE_PATH=.bundle`, `BUNDLE_FORCE_RUBY_PLATFORM=1`, `BUNDLE_IGNORE_CONFIG=1`)
  - Yarn (`YARN_CACHE_FOLDER`)
- First-time setup only on **unmarked** worktrees (marker file)
- Defensive first-time `bundle install` (`rm -rf .bundle` + explicit flags)
- `pre-commit install --install-hooks` **only** on first creation (not every entry)
- `worktree-info` and `worktree-clean` helpers

### 2.2 Database-Managed Repos (Postgres in flake.nix)

- Short Postgres Unix socket: `/tmp/pg-$WT_ID`
- Proper daemonisation using `pg_ctl start -D $PGDATA -w -t 60` (with wait loop + `initdb` guard)
- `rails db:prepare` (preferred over legacy `db:create` + `db:structure:load`)
- `worktree-clean` must stop the local Postgres daemon + remove per-worktree Postgres data

### 2.3 Lighter Repos (Bundler + pre-commit only)

- No Postgres logic
- Still need defensive bundle + pre-commit install on first creation

---

## 3. Dotfiles Wrapper (One-time Change)

Location: `~/.dotfiles` (or wherever the current `git` wrapper lives)

**Required behaviour**:

- After `git worktree add` succeeds:
  - If `flake.nix` exists in the repo root:
    - Create `.envrc` containing `use flake . --impure`
    - Run `direnv allow`
  - If no `flake.nix`: do nothing (no `.envrc`, no `direnv allow`)

This wrapper is the primary trigger for first-time setup and makes the experience deterministic.

---

## 4. Repo-by-Repo Plan

### 4.1 trade-tariff-backend (Highest priority)

**Type**: Full (manages its own Postgres)

**Current Status** (as of May 2026)
- Core hook exists on main
- Recent improvement committed on `BAU-add-pre-commit-to-flake`: proper `pg_ctl start -w` daemonisation + defensive bundle steps
- Still using legacy DB commands in some places (`db:create` + `db:structure:load`)

**Required Changes**
- Ensure first-time block uses `pg_ctl start -w -t 60` + `initdb` guard + wait loop (backend tuning: `max_wal_size=16GB`, `maintenance_work_mem=8GB`)
- Switch to `bundle exec rails db:prepare` (dev + test) for consistency
- Add full defensive BUNDLE variables (`BUNDLE_FORCE_RUBY_PLATFORM=1`, etc.)
- Ensure `worktree-clean` stops Postgres via pid file (`/tmp/pg-$WT_ID.pid`) and removes `.bundle` + `.nix`
- Verification: clean full `bundle exec rspec` run in a brand-new worktree with Postgres actually running on short socket

**Verification Criteria**
- Fresh worktree → `direnv allow` → first-time setup completes → `bundle exec rspec` loads and can run the test suite

**Owner**: Backend team + William

---

### 4.2 trade-tariff-admin (#1253)

**Type**: Full (Postgres + Yarn + Webpack)

**Current Status**
- Hardened hook pushed on `BAU-worktree-isolation-hook`
- Uses `pg_ctl start -w`, explicit `bundle install`, `bundle exec bin/webpack`
- PR description already updated with lessons

**Remaining Work**
- Final clean verification in a fresh worktree (full first-time setup + rspec)
- Confirm `worktree-clean` stops Postgres reliably

**Specific Details**
- DB names: `tariff_admin_development`, `tariff_admin_test`
- Uses `bin/webpack` (not just assets:precompile)

---

### 4.3 trade-tariff-dev-hub (#184)

**Type**: Full (Postgres + Bundler)

**Current Status**
- Hardened version just applied (proper `pg_ctl`, `bundle install` first, `db:prepare`, pre-commit)
- PR description updated

**Remaining Work**
- Clean verification in fresh worktree
- Ensure `worktree-clean` handles Postgres stop + data cleanup

**Specific Details**
- DB names: `tariff_dev_hub_development`, `tariff_dev_hub_test`

---

### 4.4 trade-tariff-frontend (#3010)

**Type**: Lighter (Bundler + Yarn + Assets + Pre-commit, no Postgres in flake)

**Current Status**
- Hardened with defensive bundle + pre-commit pattern
- PR description updated

**Required Changes**
- First-time block must run:
  - `bundle install` (defensive)
  - `yarn install --frozen-lockfile`
  - `bin/rails assets:precompile`
- Pre-commit install only on first creation

**Specific Details**
- No Postgres management (uses shared services)

---

### 4.5 identity

**Type**: Lighter (has `bin/rails` + `db:prepare`, but no Postgres management in its own flake)

**Current Status**
- Basic version exists

**Required Changes**
- Apply same defensive bundle + pre-commit pattern as frontend
- First-time: `bundle install` + `rails db:prepare`
- No Postgres daemon logic required

---

### 4.6 Lighter / Tooling Repos

**Repos**: `trade-tariff-api-docs`, `trade-tariff-classification-examples`, `trade-tariff-tech-docs`, `uktt`, and similar

**Type**: Lighter (Bundler + pre-commit, sometimes yarn)

**Pattern Required**
- Worktree detection + short `GEM_HOME` / `BUNDLE_PATH`
- Explicit `bundle install` on first entry (defensive)
- `pre-commit install --install-hooks` only on first creation
- `worktree-info` + lightweight `worktree-clean`

**No Postgres logic required.**

---

## 5. Dotfiles Wrapper (Critical One-time Change)

**Location**: `~/.dotfiles` (or equivalent)

**Required contract**:

```bash
# After real `git worktree add` succeeds
if [ -f "$WORKTREE_PATH/flake.nix" ]; then
    echo 'use flake . --impure' > "$WORKTREE_PATH/.envrc"
    (cd "$WORKTREE_PATH" && direnv allow)
fi
```

This wrapper is what makes the experience deterministic and removes reliance on developers remembering to run `direnv allow`.

---

## 6. Proposed Rollout Order

1. **Backend** – Finish verification in a truly clean worktree (reference implementation)
2. **Admin** – Re-verify with latest pattern
3. **Dev-hub** – Verify
4. Apply lighter Bundler + pre-commit version to remaining repos
5. Update `using-git-worktrees` skill doc + reference material with final pattern
6. Socialise + merge

---

## 7. Key Lessons Learned (for PRs and docs)

- Services like Postgres **must** be started with proper daemonisation (`pg_ctl start -w`) rather than `nohup ... &`.
- First `bundle install` in a worktree must be explicit and defensive to avoid system Ruby vs Nix Ruby gem conflicts.
- `pre-commit install` should only happen on first creation, not every shell entry.
- `worktree-clean` must be comprehensive (Postgres + bundle + Nix state + marker) for a true reset.
- Using `db:prepare` is more reliable than the legacy split of `db:create` + `db:structure:load`.

---

## 8. Open Questions / Decisions Needed

- Exact pid file location convention (`/tmp/pg-$WT_ID.pid` vs inside `$PGDATA`)
- Whether `worktree-clean` should also nuke any local Redis / OpenSearch state (if any)
- Ownership of the dotfiles wrapper (who maintains it long-term)

---

**Next Action**: Review this plan, provide feedback, then we can start with Backend verification + any final polish on the hook.
