# MBE Test Plan

This document catalogs the regression tests MBE should have before cutting a
release. There is currently no test framework or CI (see `CLAUDE.md`) --
this is a spec of what to verify and how, written from the tests actually
run by hand while hardening the framework's lifecycle machinery. Treat it
as a release gate checklist today; a candidate for automation (plain bash
assertion scripts, or a framework like bats-core) later.

Every test below should be run under the *actual* minimum-supported bash
(currently bash 4+; see `mbe_bash4_modernization_plan` in project memory)
and, where noted, cross-checked against the real installed shell -- several
real bugs in this hardening pass only reproduced with real `PATH` contents,
a real dependency graph, or a real terminal, not a synthetic minimal case.

## 1. Static checks (fast, run first, on every file)

- [ ] `bash -n <file>` on every module script, `install`, `bashrc`,
  `bash_profile`, `bash_aliases`, `mbe_completion`. Catches syntax errors
  before anything else runs.
- [ ] `shellcheck -S error <file>` on the same set. Error-level only --
  MBE intentionally doesn't chase every style nit, but error-level findings
  have repeatedly caught real bugs (unquoted expansions, bad redirects).
- [ ] Grep-based structural checks (cheap, catch entire bug *classes*
  found this session -- see ¶7 for the specific patterns and why each
  matters):
  - No module defines the same function name twice in one file (dead
    shadowed code -- found in `rtc`).
  - No module's `_load` declares `__<name>_dependencies` without also
    calling `_mbe_activateModules "${__<name>_dependencies[@]}"` inside
    that same `_load` (declaring is not activating -- found in 6+
    modules).
  - No module references another module's function/variable without
    that module appearing in its own `__<name>_dependencies`.
  - No unquoted `${var//pattern/replacement}` feeding directly into an
    array assignment, and no `for x in $(cmd)` / `for x in $var` where
    the loop body isn't provably safe against a value containing a
    space (see ¶6).

## 2. Install script

Run against a throwaway target (`./install -t /tmp/mbe_test_XXXX`), never
against `$HOME`, for all of the following:

- [ ] **Fresh install** into an empty target: exits 0, reports `N new, 0
  updated, 0 unchanged, 0 drifted`, and a subsequent full module load (¶3)
  succeeds.
- [ ] **Idempotent re-run** immediately after a fresh install: reports `0
  new, 0 updated, N unchanged, 0 drifted` -- proves the install is
  deterministic and doesn't touch files it doesn't need to.
- [ ] **Drift detection, no `-f`**: hand-edit an installed file, re-run
  install, confirm it's reported as drifted *and skipped* (edit survives),
  with a message telling the user to re-run with `-f` to override.
- [ ] **Drift override, `-f`**: same setup, re-run with `-f`, confirm the
  drifted file is overwritten *and* a timestamped backup of the pre-edit
  content was taken first (never silently lose local edits).
- [ ] **Dry run, `-d`**: hand-edit a file, run with `-d` against the same
  drift scenario, confirm it prints what it *would* do (including a real
  `diff -u`) without touching the filesystem, install log, or manifest
  timestamps at all.
- [ ] **Symlink mode, `-s`**: confirm every module directory gets
  individually symlinked (not the whole `modules/` dir -- `MODULES_DIR`
  itself must remain a real directory MBE can still write into), confirm
  a real login shell sources through the symlinks correctly, and confirm
  adding a *brand-new* module directory to the repo requires re-running
  `install -s` before that module is reachable (this is a known,
  documented gap, not a bug -- verify the gap still exists as expected,
  so a future change to symlinking doesn't silently "fix" it in a way
  that breaks something else).
- [ ] **AppleDouble/xattr hygiene** (macOS-specific): if the install or
  any sync path involves `tar` (e.g. syncing to a remote box), verify
  `COPYFILE_DISABLE=1 tar --no-xattrs` produces an archive with zero
  `._*` entries (`tar tzf archive.tar.gz | grep '\._'` should be empty).
  A plain `tar czf` on macOS pollutes the archive with AppleDouble
  sidecar files that break extraction on Linux.

## 3. Module lifecycle: activation

For each check, prefer running against the *entire* real module set in one
sweep (not a hand-picked subset) -- the leak-detection sweep in ¶4 is the
one test in this whole document that most reliably catches new bugs,
precisely because it's exhaustive rather than representative.

- [ ] **Full sweep, standalone activation**: in one fresh shell (or
  `env -i HOME=... PATH=... bash -c '...'` for full isolation from the
  ambient environment -- see ¶8 on why isolation matters), activate every
  module in the repo one at a time via `_mbe_activateModules <name>` (not
  just the ones in `MODULES_INIT` -- a module that only works when
  something else happens to have already activated its dependencies is
  exactly the bug class this catches). Confirm each activates without
  error.
- [ ] **Dependency chain correctness**: for at least one real multi-level
  chain in the current module set (e.g. `eclipse` -> `java` -> `platform`
  + `utils`), activate the top-level module standalone and confirm every
  dependency in the chain ends up in `MODULES_ACTIVE`/
  `MODULES_ACTIVE_SET`.
- [ ] **Function-tracking attribution, no cross-contamination**: for the
  same chain, confirm `MBE_MODULE_FUNCS[<each module in the chain>]`
  contains *only* that module's own functions -- diff every pair in the
  chain and confirm zero overlap. This is the test that catches
  recursion-attribution bugs (a dependency's functions/vars getting
  credited to whatever module happened to pull it in), which is exactly
  the failure mode the whole `_MBE_CLAIMED_FUNCS`/`_MBE_CLAIMED_VARS` +
  `_MBE_ACTIVATE_DEPTH` machinery exists to prevent. If this mechanism is
  ever touched, re-run this test with the deepest chain available at the
  time, not a shallow one -- a shallow chain (depth 2) can pass while a
  deeper one (depth 3+) still misattributes.
- [ ] **Var-tracking attribution, no cross-contamination**: same as
  above, but for `MBE_MODULE_VARS`. Additionally confirm `PATH`/
  `LD_LIBRARY_PATH`/`MANPATH`/`INCLUDE` never appear in *any* module's
  tracked var list (these are deliberately excluded -- `_mbe_buildpath`
  owns them exclusively).
- [ ] **`_mbe_buildpath` runs once per top-level activation, not once per
  recursion level**: activate a module with a multi-level dependency
  chain and confirm (e.g. via a `DEBUG`-echo count, or by instrumenting
  `_mbe_buildpath` temporarily) that it runs exactly once for the whole
  call tree. Regressed once already during this session's development
  (fixed by only calling it when `_MBE_ACTIVATE_DEPTH` unwinds to 0) --
  the bug was invisible except through its downstream symptom (var
  misattribution), so test the mechanism directly, not just its
  symptoms.
- [ ] **Re-sourcing preserves state (`resource`)**: activate several
  modules, note `MODULES_ACTIVE`/`MBE_MODULE_FUNCS`/`MBE_MODULE_VARS`,
  run `resource` (re-source `.bashrc`), confirm all three are unchanged
  and that functions defined by already-active modules are still
  callable. This is what the `if ! declare -p ... ; then declare -gA
  ...; fi` guards around every framework-level associative array exist
  to protect -- a regression here would show up as silently-reset state
  on every `resource`, not a crash.

## 4. Module lifecycle: deactivation (the most valuable test in this suite)

- [ ] **Full sweep, activate-then-deactivate-everything, zero leaks**:
  activate every module in the repo (all ~40, not a subset), then
  deactivate every one of them (`_mbe_deactivateModules -y <name>`, using
  `-y` to avoid blocking on the cascade-confirmation prompt in an
  unattended run), and after each deactivation assert:
  - every function in that module's *pre-deactivation* `MBE_MODULE_FUNCS`
    entry is now undefined (`declare -F <name>` fails).
  - every variable in that module's *pre-deactivation* `MBE_MODULE_VARS`
    entry is now unset (`[ -z "${!varname+set}" ]`).
  - after the full sweep, `MODULES_ACTIVE` contains only `mbe` (the
    bootstrap module, which never goes through
    `_mbe_activateModules`/`_mbe_deactivateModules` and so is expected to
    remain).
  This exact test (with this exact structure) caught nine modules with
  drifted `__<name>_functions` arrays, a `_mbe_buildpath` recursion bug, a
  `java`/`sdkman` `JAVA_HOME` misattribution bug, and confirmed the fix
  for all of them, in a single run. It is the highest-value test in this
  document -- if only one test survives triage into automation, it should
  be this one.
- [ ] **Cascade-deactivate, dependents warned and included**: activate a
  module with an active dependent (e.g. `java` with `maven` also active),
  deactivate the base module with `-y`, confirm the dependent is listed in
  the warning output *and* actually deactivated (not just warned about).
- [ ] **Cascade-deactivate, transitive dependents**: construct or find a
  3-level chain (`X` depends on `maven` depends on `java`) and confirm
  deactivating `java` catches `X` too, not just the direct dependent
  `maven`. (No real 3-level chain existed in the module set as of this
  writing -- this may require a synthetic fake-module fixture; see the
  session's own synthetic test for the exact pattern.)
- [ ] **Cascade-deactivate, confirmation prompt behavior** (interactive
  path, not just `-y`): with dependents present and no `-y`, confirm the
  prompt appears, and that each of `y`, `Y`, `n`, `N` (first-letter,
  case-insensitive) produces the correct result -- `y`/`Y` proceeds and
  cascades, `n`/`N` aborts with *nothing* deactivated. Confirm a module
  with zero dependents produces *no* prompt at all (regression risk: an
  overly broad "always ask" change would break every existing
  non-interactive `mbe deactivate` call site).
- [ ] **No dependents, no prompt, silent success**: deactivate a genuine
  leaf module (no other active module depends on it) and confirm it
  deactivates immediately with no prompt -- this is the *default* path
  and must never regress into always prompting.

## 5. `_mbe_cleanpath` (path/var value correctness)

Test the function directly, not just through `_mbe_buildpath`, since it's
cheap to isolate and several bugs here only reproduce with specific input
shapes:

- [ ] Basic dedup: `"/usr/bin:/usr/bin:/bin"` -> `/usr/bin:/bin`.
- [ ] Nonexistent path removal: an element pointing at a directory that
  doesn't exist is dropped.
- [ ] **Path element containing a space** (e.g. a real
  `/Applications/JetBrains Toolbox/bin`-shaped path): must survive as one
  element, not get split into two. This was the original motivating bug
  for the `_mbe_cleanpath` rewrite.
- [ ] **Leading, trailing, and doubled colons** (`":/usr/bin"`,
  `"/usr/bin:"`, `"/usr/bin::/bin"`): must not crash and must not
  reintroduce an empty ("current directory") element into the cleaned
  output. This is the bash "bad array subscript on empty string key"
  bug found *while fixing* the space-in-path bug above -- a cautionary
  example of a fix introducing a new bug that only reproduces with
  realistic input, not the synthetic case the fix was tested against
  first.
- [ ] Empty input -> empty output, no error.
- [ ] Single-element input -> that element, unchanged.
- [ ] All-nonexistent input -> empty output, no error.
- [ ] **No variable leakage**: call the function, then check that its
  internal locals (`pathelem`, `seen`, etc.) are not visible/set in the
  calling scope afterward.
- [ ] **Full integration**: a real `resource` in a real login shell with a
  real (long, messy) `PATH` completes without error and produces a
  sane-looking `PATH`. Synthetic unit tests on `_mbe_cleanpath` alone did
  not catch the empty-array-key bug -- only running it against a real
  `PATH` (which had a doubled colon) did.

## 6. IFS / word-splitting audit (repeat this sweep after any future change to string-processing code)

- [ ] Grep for unquoted `${var//pattern/replacement}` assigned directly
  into an array (`arr=( ${var//x/y} )` with no quotes) -- splits on
  whitespace via `$IFS`, not the intended delimiter.
- [ ] Grep for `for x in $(cmd)` or `for x in $var` and manually confirm
  each hit's value can never contain a space (safe cases found this
  session: iterating function names, variable names, or module names,
  none of which can contain whitespace in bash) or is otherwise provably
  safe. Anything iterating file paths, user-supplied strings, or
  anything from `find`/`ls`/similar unquoted is a candidate bug.
- [ ] Grep for unquoted `$@`/`$*` built into a string that is later
  `eval`'d (`cmd="foo $*"; eval "${cmd}"`) -- this both re-introduces
  word-splitting *and* lets shell metacharacters in the arguments be
  re-interpreted by `eval`, which is a command-injection shape if any
  argument is ever influenced by external input. Prefer arrays
  (`cmd=(foo "$@"); "${cmd[@]}"`) or, when the goal is genuinely just
  "run this program with these space-separated flags," a direct
  unquoted call without `eval` (`prog ${FLAGS_VAR}`) -- word-splitting
  without a second `eval` parse pass is meaningfully safer.
- [ ] Confirm any legitimate `IFS=X read ...` usage scopes the
  assignment to that single command (`IFS=X read -ra arr <<< "$str"`,
  no separate `IFS=X` statement on its own line without a matching
  restore) -- this codebase's existing correct examples are in
  `modules/prompt/prompt`, `modules/intellij/intellij`, `bash_aliases`,
  and `install`.

## 7. Module contract conventions (mechanical, one-time-per-module, re-check when adding a module)

These are cheap to check per-module and were the source of most bugs found
this session -- worth a lint pass whenever a module is added or edited, not
just at release time:

- [ ] `__<name>_dependencies` exists, and `_<name>_load` calls
  `_mbe_activateModules "${__<name>_dependencies[@]}"` (declaring without
  activating was found in `rar`, `rtc`, `scite`, `vim`, `perl`, `git`,
  `mongo`, `utils` -- eight modules, not an edge case).
- [ ] Every symbol (function or variable) the module references but
  doesn't define itself is owned by a module listed in its own
  `__<name>_dependencies` (found missing in `rtc` -> `java`, independent
  of the above).
- [ ] No module defines the same function twice (found in `rtc`).
- [ ] If a module defines aliases (not just functions), it maintains a
  `__<name>_aliases` array and unaliases them in `_<name>_unload` --
  functions are auto-tracked (see `MBE_MODULE_FUNCS`), aliases are not
  (see `CLAUDE.md`'s "Automatic function tracking" section for why).
  Cross-check the array actually lists every alias the module defines
  (found incomplete in `intellij` -- missing 4 of 8).
- [ ] A module's `_setpath` should be safe to call repeatedly with no
  side effects beyond what it's supposed to do on every call (it *will*
  be called on every `_mbe_buildpath`, i.e. every module activate/
  deactivate anywhere in the shell, not just its own). Specifically:
  avoid forking expensive subprocesses on every call when the result
  could be cached once at `_load` time instead (found in `homebrew`,
  which forked `brew shellenv` *and* `brew --prefix` on every rebuild;
  fixed by caching `brew --prefix`'s result at `_load`).

## 8. Test environment notes

- **Isolation matters more than it looks.** Several bugs this session
  only reproduced under `env -i HOME=... PATH=/usr/bin:/bin:/opt/homebrew/bin
  bash -c '...'` (a deliberately minimal environment) and did *not*
  reproduce in an already-warmed-up interactive shell with ambient state
  left over from prior testing (e.g. a leftover `JAVA_BITS` in the
  environment suppressed the var-tracking test from ever exercising the
  "claim a newly-set variable" path). Prefer isolated environments for
  correctness tests; reserve real-interactive-shell testing for
  confirming the fix also works where the user actually lives.
- **`-y` exists specifically to make deactivation scriptable.** Any
  automated version of the ¶4 sweep must pass `-y` to
  `_mbe_deactivateModules`/`mbe deactivate` -- without it, a deactivation
  with dependents blocks on `read` waiting for a terminal that isn't
  there, which manifests as a silent hang, not a clean failure. (This
  exact hang happened during this session's own testing before `-y`
  existed.)
- **Piping fake stdin into a whole test script is not equivalent to
  answering one prompt.** `yes y | some_test_script` redirects stdin for
  everything the script does, not just the one `read` you're trying to
  satisfy -- this produced a confusing, never-fully-root-caused failure
  during this session (a module deactivation silently doing nothing) that
  went away entirely once `-y` was used instead of stdin redirection.
  Prefer flags over piped stdin when testing anything with an interactive
  prompt.
