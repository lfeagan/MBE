# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

MBE (Modular Bash Environment) is a pure-bash framework for managing `.bashrc`/`.bash_profile` configuration as a set of loadable/unloadable "modules." There is no build step, package manager, or test suite — it's a set of shell scripts sourced into an interactive bash session. Each module typically configures a tool (Java, git, vim, Eclipse, Maven, Informix, etc.) by defining functions and, when active, contributing to `PATH`/`LD_LIBRARY_PATH`/`MANPATH`.

## Commands

There is no build/lint/test tooling. The only meaningful commands are:

- `./install [-b|-B] [-t <target>]` — installs `bashrc`, `bash_aliases`, `bash_profile`, `mbe_completion`, and `modules/` into `~/.mbe` (or `-t <target>`). `-B` (default) backs up existing dotfiles to `~/.mbe/backup` first; `-b` disables backup. `-d` runs in debug/dry-run mode without touching the filesystem.
- To sanity-check a shell script change, source it in a bash subshell or run `bash -n <file>` for a syntax check — there is no CI.
- Inside a running MBE-enabled shell: `mbe list [all|active|inactive]`, `mbe activate <module>`, `mbe deactivate <module>` manage modules at runtime; `resource` (defined in `bashrc`) re-sources `~/.bashrc` and `~/.bash_aliases` after edits.

## Architecture

### Load sequence

`bash_profile` sources `bashrc`. `bashrc` sets `MBE_DIR=~/.mbe`, `MODULES_DIR`, and `MODULES_INIT` (the list of modules to auto-activate), sources `modules/mbe/mbe.conf` for preferences, then sources `modules/mbe/mbe` and calls `_mbe_load` followed by `_mbe_activateModules "${MODULES_INIT[@]}"`. After modules load, `bashrc` continues with general shell setup (umask by host trust level, `HIST*` vars, `shopt`s, completions, key bindings), then sources `~/.bash_aliases` and `mbe_completion`.

### Module contract

Every module lives at `modules/<name>/<name>` (the entry-point script) with an optional `modules/<name>/<name>.conf` (user-overridable preferences, sourced before the module script). `modules/mbe/template` is the canonical skeleton for creating a new module — copy it and do a `%s/oldname/newname/gc`.

#### Lifecycle functions

A module defines these functions, all prefixed `_<name>_`:

- `_<name>_load` — called on activation (from `_mbe_activateModules`, after the module script itself is sourced). Declares dependencies via `_mbe_activateModules "${__<name>_dependencies[@]}"` for any modules it needs (e.g. `java` depends on `mbe`, `platform`, `utils`), sources the module's own `.conf` if it has one, and sets up aliases/functions. Do not call `_mbe_buildpath` here directly — `_mbe_activateModules` does that once, after `_load` returns.
- `_<name>_unload` — called on deactivation (from `_mbe_deactivateModules`). Iterates `__<name>_functions` and `unset`s each one; if the module defined aliases outside that array, unalias them too (see `intellij`).
- `_<name>_setpath` — called by `_mbe_buildpath` for every *active* module, on every path rebuild (module (de)activation, or an explicit `_mbe_buildpath` call). Contributes to `PATH`/`LD_LIBRARY_PATH`/`MANPATH`/`INCLUDE` for this module only — never assign those variables outside this hook (see "Path management" below); everything else (e.g. `JAVA_HOME`) is fine to set here directly.
- `_<name>_complete` — bash completion handler, dispatched by `mbe_completion`'s `_mbe_complete` when the user is tab-completing `mbe <name> ...`. Reads the completion globals `cur`, `prev`, `COMP_CWORD`, and `module_function` that `_mbe_complete` sets up before dispatching — a module's `_complete` does not set these itself.

Beyond the lifecycle functions, a module may define arbitrary subcommands invoked as `mbe <name> <command> [args...]`, which the generic dispatcher in `mbe()` (`modules/mbe/mbe`) resolves to `_<name>_<command> [args...]`. `_setpath`/`_load`/`_unload`/`_complete` are just reserved names in that same namespace, called directly by the framework rather than by a user typing `mbe <name> setpath`. Existing modules split inconsistently between `_<name>_info` and `_<name>_usage` for a human-readable description subcommand — pick `_<name>_info` for new modules; do not "fix" the existing split by renaming, since that changes the `mbe <name> <command>` CLI surface for anyone using it.

#### Array naming convention

Module-local helper arrays are **always double-underscore-prefixed**, matching the framework's own `__mbe_features` (in `modules/mbe/mbe.conf`):

- `__<name>_dependencies` — modules to activate before this one; passed straight to `_mbe_activateModules` in `_load`. Most single-dependency modules just list `'mbe'`.
- `__<name>_functions` — every function name this module defines; `_unload` iterates this to `unset` them. **This array's declared name and the name `_unload` reads must match exactly** — a single vs. double underscore typo here means `unload` silently does nothing (found and fixed live instances of this in `developer`, `netclient`, and `clearcase`). When adding a function to a module, add it to this array too.
- `__<name>_features` — only used by `mbe` and `developer` today; a list of sub-scripts within the module's own directory to source and `_load` as part of loading the module itself (see `_mbe_load` in `modules/mbe/mbe`). Most modules don't need this.

A few modules (`clearcase`, `mongo`, `platform`, `intellij`) previously used single- or no-underscore names for these; they've been normalized to match the convention above. When writing a new module or fixing an old one, use `__<name>_dependencies` / `__<name>_functions` / `__<name>_features` — never `_<name>_...` or `<name>_...` for these specific arrays.

### Path management (critical invariant)

`modules/mbe/mbe` archives the OS-provided `PATH`, `LD_LIBRARY_PATH`, `MANPATH`, `INCLUDE` into `ORIG_*` variables exactly once per shell (guarded by `if [ -z "${ORIG_PATH}" ]`). `_mbe_buildpath` (in `modules/mbe/mbe`) is the *only* function that should assign these variables: it resets them to `ORIG_*`, then calls `_<module>_setpath` for every module in `MODULES_ACTIVE`, then prepends `USER_PATHS`/`USER_LD_LIBRARY_PATHS`/`USER_MANPATHS`, then deduplicates and drops nonexistent directories via `_mbe_cleanpath`. Consequently: never append directly to `PATH` in a module — implement `_<module>_setpath` instead, and call `_mbe_buildpath` to apply it. `_mbe_activateModules`/`_mbe_deactivateModules` call `_mbe_buildpath` automatically after (de)activating.

### Platform detection

`modules/platform/platform` is a near-universal dependency. `_platform_config` normalizes `KERNELNAME`/`KERNELBITS`/`CPUTYPE`/`BSDARGS` across AIX, HP-UX, IRIX64, Darwin, Linux, SunOS, OSF1, Cygwin, and Windows_NT, since bash's built-in `MACHTYPE`/`OSTYPE`/`HOSTTYPE` vary too much across distros to rely on directly. `_platform_platformpath` derives `PLATFORMPATH`/`PLATFORMPATH32` (e.g. `Linux/64/x86_64`) from those, and `_platform_toolspath` builds `TOOLSPATH`/`TOOLSPATH32`/`TOOLSPATHGENERIC` under `TOOLSPATH_BASE` (default `/opt/tools`). Tool modules (java, maven, ant, eclipse, etc.) locate versioned installs under `${TOOLSPATH}/<ToolDir>/<Creator>/<Version>` using this platform path — see `_java_buildjavahomestring` for the pattern.

### Preferences and overrides

`modules/mbe/mbe.conf` (and each module's own `<name>.conf`) hold user-tunable defaults (e.g. `USER_EDITORS`, `USER_PAGERS`, `SECURE_HOSTS`/`SHARED_HOSTS` umask lists, `TOOLSPATH_BASE`). These are meant to be edited per-installation via `mbe <module> conf` / `_mbe_editModuleConf`, not hardcoded into module logic.

### Naming/style conventions to preserve

- Private/callable functions use a single leading underscore, e.g. `_mbe_activateModules`, `_<name>_load`; module-internal arrays use double underscore (`__<name>_...`) as described above.
- `DEBUG echo "..."` (defined in `modules/mbe/mbe`) is the standard trace-logging idiom, gated on `_DEBUG=on`; prefer it over ad hoc `echo` when adding diagnostics.
- Every file carries the Apache 2.0 license header block — keep it when creating new module files (base new ones on `modules/mbe/template`, not a blank file).
