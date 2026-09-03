# MBE — Modular Bash Environment

MBE turns a `.bashrc` from a monolithic, ever-growing pile of `if`-blocks
guarding tool-specific setup into a set of independent, loadable/unloadable
**modules** — one per tool (Java, git, vim, Eclipse, Maven, Informix, and
about 35 others). Each module knows how to configure itself and stays out of
every other module's way. There's no build step, no package manager, no
daemon: it's pure bash, sourced into your interactive shell.

This document explains the *why* and the *how*. For the mechanical
module-authoring contract (lifecycle functions, naming conventions, path
management invariants), see [CLAUDE.md](CLAUDE.md) — that's the reference
for writing or editing a module. This README is the pitch and the mental
model.

## Getting started

MBE requires bash 4 or later. macOS ships Apple's frozen bash 3.2 as
`/bin/bash` for licensing reasons, so on a Mac you'll need a newer bash on
`$PATH` (e.g. `brew install bash`) before installing. If you do end up
running under bash 3.2 anyway (for example inside `sudo bash`, which
resolves to `/bin/bash` even when your login shell is a newer Homebrew
bash), `bashrc` detects it and falls back to a bare prompt with a warning
rather than failing halfway through loading modules.

After `brew install bash`, make it your login shell so new terminal
windows use it (not just interactive subshells):

```sh
BREW_BASH="$(brew --prefix)/bin/bash"     # /opt/homebrew/bin/bash on Apple
                                           # Silicon, /usr/local/bin/bash on Intel
grep -qxF "${BREW_BASH}" /etc/shells || sudo sh -c "echo ${BREW_BASH} >> /etc/shells"
chsh -s "${BREW_BASH}"
```

Then open a new terminal window (not just a new tab in some terminal apps,
which can reuse the old shell) and confirm with `echo $BASH_VERSION`.

```sh
git clone git@github.com:lfeagan/MBE.git
cd MBE
./install          # or ./install -s -- see below
```

`install` asks you to confirm the target directory (`$HOME` by default),
then backs up any dotfiles it's about to replace and installs `bashrc`,
`bash_aliases`, `bash_profile`, `mbe_completion`, and `modules/` into
`~/.mbe`. Two install modes:

- **Plain (default)** — copies files in. Safe, but if you hand-edit an
  installed file (e.g. `~/.bashrc`) afterward, the next `./install` detects
  that drift and skips it rather than clobbering your change (use `-f` to
  force-overwrite anyway).
- **`-s` (symlink)** — `~/.bashrc`, `~/.bash_profile`, `~/.bash_aliases`, and
  every `~/.mbe/modules/<name>` become symlinks back into this checkout, so
  edits to the repo take effect in your next new shell with no re-install
  step. This is what you want if you're actively developing modules; keep
  the checkout in a stable location if you use it, since the symlinks point
  there directly.

Open a new terminal (or `source ~/.bashrc`) and confirm it worked:

```sh
mbe list active      # modules loaded in this shell right now
mbe list info        # every available module + what it does
```

From there:

- **Change what loads automatically** — edit the `MODULES_INIT` array near
  the top of `bashrc` (in this checkout, then re-run `./install` if you
  didn't use `-s`), and open a new shell.
- **Turn a module on/off for just this shell** — `mbe activate <module>` /
  `mbe deactivate <module>`, no edit or restart needed.
- **Tune a module's defaults** — its preferences live in
  `modules/<name>/<name>.conf`; edit that file directly with your editor.
- **See what a module actually does before turning it on** — `mbe list
  info` (or the [Module catalog](#module-catalog) below).

## The problem this solves

A `.bashrc` that's grown for years across many machines tends to converge on
one of two failure modes:

- **Everything, always.** Every tool you've ever used gets sourced on every
  shell, whether or not it's installed, needed, or even *correct* on this
  host — `JAVA_HOME` pointing at a path that only exists on your work laptop,
  a Maven alias clashing with a tool you use for something else, a `PATH`
  three hundred characters long because nothing ever gets removed, only
  added.
- **Copy-paste per machine.** You maintain a subtly different `.bashrc` per
  host, because each has a different combination of tools installed, and
  keeping one universal file in sync by hand isn't worth the effort.

Both cost you real time — a shell that takes a second to start because it's
doing work you don't need, a `PATH` collision that breaks a build in a way
that takes twenty minutes to diagnose, an alias that means something
different on your laptop than on the server you just SSH'd into.

MBE's answer: don't try to build one `.bashrc` that's correct everywhere.
Build a shell that can be told, per session, exactly which tools it needs to
know about — and make turning a tool on or off a single command with no
side effects on anything else.

## Design ethos

- **A module either isn't there, or it's fully there.** There's no
  intermediate state where a module is "half-loaded" — sourcing a module's
  script and calling its `_load` function defines everything the module
  needs (functions, aliases, `JAVA_HOME`-style env vars) or nothing at all.
  Deactivating reverses that completely: every function it defined is
  `unset`, every variable it set is restored, every `PATH` element it
  contributed disappears. No stale functions haunting your shell after you
  thought you turned something off.

- **The framework tracks what a module did, so the module doesn't have to.**
  Early versions of MBE required each module to hand-maintain a list of every
  function and alias it defined, purely so `_unload` knew what to clean up.
  That list drifted from reality constantly — it's easy to add a new
  function to a module and forget to also add it to the tracking array, and
  the failure mode (a stale function surviving deactivation) is invisible
  until something else collides with it later. MBE now diffs `declare -F`
  and the exported-variable set before and after a module loads, and derives
  exactly what changed — automatically, with no way to drift. See
  "Automatic function/variable tracking" in CLAUDE.md for the mechanism.

- **`PATH` is a build artifact, not a variable you mutate.** Every module
  that touches `PATH`, `LD_LIBRARY_PATH`, `MANPATH`, or `INCLUDE` does so
  through a `_setpath` hook, never by appending directly. The framework
  archives the OS-provided values once per shell, then *rebuilds* the whole
  path from scratch — original values plus every active module's
  contribution — on every activate/deactivate. This means the order modules
  were loaded in never matters, deactivating a module can never leave a
  dangling path fragment behind, and there's a single place
  (`_mbe_cleanpath`) that owns deduplication and dropping nonexistent
  directories, instead of that logic being reinvented per module.

- **Dependencies are explicit and recursive, not assumed.** A module that
  needs another (`eclipse` needs `java`, `platform`, and `utils`) declares
  that in its own `_load`, and the framework activates the dependency first
  — however deep the chain goes. You never have to remember "oh, I need to
  turn on `platform` before `java` will work"; asking for `eclipse` gets you
  the whole chain, correctly, every time. Deactivation runs the same logic
  in reverse: turning off a module that something else still depends on
  warns you and offers to cascade, rather than silently leaving a dependent
  module partially broken.

- **Fully reversible, testable in isolation.** Because activation and
  deactivation are exact inverses (see the two points above), MBE can be
  tested by activating every module in the repo, deactivating all of them,
  and asserting the shell ends up in exactly the state it started in — no
  leaked functions, no leaked variables, no leftover `PATH` entries. That
  sweep (see `TESTING.md` §4) is the single highest-value test in the whole
  suite, and it only works because the design makes "fully off" a real,
  checkable state rather than an aspiration.

- **Portable across UNIX flavors, not just Linux.** MBE grew up moving
  between AIX, HP-UX, IRIX, Solaris, Darwin, and Linux, on a mix of `bash` 3
  through 5. `modules/platform/platform` centralizes the differences (kernel
  name, bit width, CPU type) so every other module can ask "where does the
  versioned tool install for *this* platform live?" without re-deriving
  platform quirks itself.

## How it works

1. **`bash_profile`** sources **`bashrc`**, which is the entry point for
   everything else.
2. `bashrc` sets `MBE_DIR` (default `~/.mbe`), `MODULES_DIR`, and
   `MODULES_INIT` — the list of modules to auto-activate on shell start —
   then sources the `mbe` module itself and calls `_mbe_activateModules
   "${MODULES_INIT[@]}"`.
3. Each module lives at `modules/<name>/<name>`, with an optional
   `modules/<name>/<name>.conf` for user-overridable preferences. Activating
   a module sources its script and calls its `_<name>_load` function, which
   pulls in whatever dependencies it declares and sets up aliases/functions.
   The framework then calls `_<name>_setpath` (along with every other active
   module's `_setpath`) to rebuild `PATH` and friends from scratch.
4. `bashrc` continues with general shell setup that doesn't belong to any
   one module (history size, `shopt`s, key bindings), then sources
   `~/.bash_aliases` and `mbe_completion` for tab-completion of the `mbe`
   command itself.

From an interactive shell, you drive modules directly:

```sh
mbe list [all|active|inactive]   # what's currently loaded
mbe list info                    # every module + its one-line description
mbe activate <module>            # turn a module on (and its dependencies)
mbe deactivate <module>          # turn a module off (warns/cascades to dependents)
resource                         # re-source .bashrc + .bash_aliases after an edit
```

Installation is handled by `./install`, which copies (or, with `-s`,
symlinks) `bashrc`, `bash_aliases`, `bash_profile`, `mbe_completion`, and
`modules/` into `~/.mbe`. It detects drift (a hand-edited installed file)
and refuses to clobber it without `-f`, takes a timestamped backup before
any overwrite, and supports `-d` for a dry run that shows exactly what
would change. See `install -h` for the full flag set.

## What you get out of it

- **Fast, minimal shells.** Only the modules in `MODULES_INIT` (or ones you
  explicitly activate) do any work. A shell that doesn't need Eclipse or
  Informix doesn't pay for them.
- **One shared codebase across every machine you use.** The same `modules/`
  tree works on a dev laptop, a build server, and a remote box you SSH into
  occasionally — each just activates a different subset via its own
  `MODULES_INIT`, without maintaining a divergent copy of the whole
  `.bashrc`.
- **No cross-tool interference.** Two modules that both want to define a
  `run` alias, or that need mutually exclusive versions of the same tool on
  `PATH`, don't fight over global state — you activate one, use it, then
  deactivate it and activate the other, and the framework guarantees a clean
  handoff.
- **Confidence that "off" really means off.** Deactivating a module is not a
  best-effort cleanup you have to double check — it's mechanically derived
  from what the module actually did, so there's nothing left to audit by
  hand.
- **A real regression-test surface.** Because module (de)activation is
  deterministic and side-effect-free by construction, it's testable with an
  ordinary bats-core suite (see `test/`) and CI (see `.github/workflows/`) —
  something that's much harder to bolt onto a hand-rolled, order-dependent
  `.bashrc`.

## Repository layout

```
bashrc, bash_profile, bash_aliases   entry points sourced into an interactive shell
mbe_completion                       tab-completion for the `mbe` command
install                              installs the above + modules/ into ~/.mbe
modules/<name>/<name>[.conf]         one directory per module
modules/mbe/                         the framework itself (activation, path building, CLI)
modules/mbe/template.skel            starting point for a new module
test/                                bats-core test suite (+ bats-support/assert/file submodules)
CLAUDE.md                            module-authoring contract and naming conventions
TESTING.md                           manual + automated test plan and rationale
```

## Module catalog

One line per module (`mbe list info` prints this same catalog live, since it
reads each module's own `_<name>_info`/`_<name>_usage` function rather than
duplicating it here):

| Module | Description |
| --- | --- |
| `ant` | Configures Apache Ant |
| `brlcad` | Configures US ARMY BRLCAD Design Program |
| `clearcase` | Configures IBM Rational ClearCase |
| `colors` | Defines human-friendly bash color escape-sequence variables (`__colors_red`, `__colors_blue`, ...) for prompts/output |
| `cscope` | Configures cscope |
| `developer` | Sources per-feature dev-tool path scripts declared in `__developer_features` |
| `dia` | Adds the Dia diagram editor's bin/man to PATH/MANPATH if installed at `/opt/dia-0.96` |
| `eclipse` | Configures and launches Eclipse-family IDEs with the right JVM/bits/locale (`mbe eclipse config\|run\|list\|cd\|cdworkspace`) |
| `gcc` | Configures the GNU C compiler |
| `git` | Installs git via Homebrew if missing; adds log-graph aliases (`glgga`, `glods`) |
| `homebin` | Adds `$HOME/bin` to `$PATH` |
| `homebrew` | Wires up Homebrew's PATH/MANPATH/INFOPATH via `brew shellenv`; other modules use `_homebrew_ensureInstalled` to install formulas on demand |
| `ibmxlc` | Configures the IBM XL C/C++ Compiler |
| `icscope2` | Configures the Informix cscope suite (a ClearCase/Informix version aware framework for cscope access) |
| `informix` | Tools for retrieving, configuring, and checking out Informix IDS/CSDK builds from a repo (`ifxlist`, `idsconfig`, `idscheckout`, `ifxenv`, ...) |
| `intelcc` | Configures the Intel C/C++ Compiler Suite |
| `intellij` | Provides JetBrains IDE launchers (`intellij`, `pycharm`, `webstorm`, ...), `idea <repo>` to open a matched git repo directly, and `proj <repo>` to cd into it |
| `java` | Configures Java |
| `lotusnotes` | Adds `/opt/ibm/lotus/notes` to PATH |
| `macports` | Enables MacPorts bash completion if installed under `/opt/local` |
| `maven` | Configures Apache Maven |
| `mbe` | The framework itself (module activation, path building, the `mbe` CLI) |
| `mongo` | Configures MongoDB |
| `msyteclaude` | Environment for the mSyte Claude Code plugins (msyte-devops, msyte-service, ...) |
| `netclient` | Adds AT&T NetClient's `/opt/agns/bin` to PATH if present |
| `opengl` | Exports OpenGL/X11 include and library flags (`OGL_INC_LOC`, `OGL_LIB_LOC`, `X_LIB_LOC`) |
| `openwin` | Adds Sun OpenWindows' `/usr/openwin/bin` to PATH if present |
| `pathfinder` | Routes `open` on directories to Path Finder instead of Finder (Darwin only) |
| `perl` | Configures Perl |
| `platform` | Detects `KERNELNAME`/`KERNELBITS`/`CPUTYPE`/`PLATFORMPATH`/`TOOLSPATH` across OSes; near-universal dependency for other modules |
| `prompt` | Configures PS1 (colors, titlebar, weather) based on light/dark terminal background detection |
| `rar` | Adds the 32-bit RAR archiver tools (under `TOOLSPATH32`) to PATH |
| `rtc` | Configures IBM Rational Team Concert's Command-Line SCM Tools |
| `sauerbraten` | Launches the Sauerbraten game (`run`) with optional console logging and Mumble overlay support |
| `sbin` | Configures various `sbin` paths (`/sbin`, `/usr/sbin`, `/usr/local/sbin`, `/opt/local/sbin`) |
| `scite` | Configures the path to the SciTE editor |
| `sdkman` | Wires up SDKMAN (owns `JAVA_HOME`/PATH for Java, Maven, Gradle, etc.) |
| `sunstudio` | Configures paths for Sun Studio development tools |
| `userid` | Configures the Informix `userid` privilege-escalation executable; `ur()` falls back to `sudo` if it's absent |
| `usrlocalbin` | Adds `/usr` and `/opt` directories to PATH, MANPATH, and LD_LIBRARY_PATH |
| `utils` | Bash shell utility functions |
| `vim` | Configures Vim, installing it via Homebrew if missing, preferring a custom build under `TOOLSPATH` if present |
| `xcode` | Configures Apple Xcode |

## Writing a new module

Copy `modules/mbe/template.skel` to `modules/<name>/<name>` and rename
`oldname` → `<name>` throughout. See CLAUDE.md's "Module contract" section
for the lifecycle functions you need to fill in (`_<name>_load`,
`_<name>_unload`, `_<name>_setpath`, `_<name>_complete`) and the array-naming
conventions (`__<name>_dependencies`, etc.) that keep a new module
consistent with the rest of the framework.
