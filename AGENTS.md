# AGENTS.md

Guidance for AI agents working in this repository. See <https://agent-rules.org/>.

## Overview

Adam's personal UNIX shell environment: zsh and bash configuration files plus a
large collection of utility scripts. Targets zsh/bash on Linux (historically
also Solaris/FreeBSD, POSIX-oriented). See `README.md` for the user-facing tour.

## Layout

- `.zshrc`, `.zshrc.d/` — interactive zsh config; `.zshrc.d/` files are sourced
  via the hook runner (see below).
- `.zshenv` — zsh config for interactive *and* non-interactive shells.
- `.bashrc`, `.bashenv`, `.bash_profile` — the bash equivalents.
- `.shared_env`, `.shared_rc`, `.shared_env.d/`, `.shared_rc.d/` — config shared
  by any Bourne-compatible shell (`.shared_env` = always, `.shared_rc` =
  interactive only).
- `.zsh/functions/` — autoloaded zsh functions and completion functions.
- `bin/` — ~170 standalone utility and wrapper scripts (see `README.md` for the
  annotated list).
- `lib/` — helper libraries, including `lib/perl5/Sh.pm` and `lib/libhooks.sh`.
- `t/` — test suite.
- `doc/` — documentation, e.g. `doc/ConfigHooks.org`.

## Hook-runner mechanism

Composite config is built from multiple files in a `foo.d/` directory rather
than one monolithic file. Key pieces:

- `.zsh/functions/find_hooks` — finds applicable hook files under a `foo.d/`
  hierarchy.
- `.zsh/functions/run_hooks` — sources the hook files found by `find_hooks`.
- `lib/libhooks.sh` — concatenates hook files into a single config file for
  external consumers (`ssh`, `mutt`, `crontab`, …).

`.zshrc` drives most loading through `run_hooks` (e.g. `run_hooks .zshrc.d`).
See `doc/ConfigHooks.org` for the design.

## Testing

The test suite under `t/` uses git's own test harness (Junio Hamano's
`test-lib.sh`), with tests named `t[0-9][0-9][0-9][0-9]-*.sh`.

```bash
cd t && make test      # run all tests
cd t && make prove     # run via prove(1)
cd t && ./t0001-mv-merge.sh   # run a single test directly
```

## Deployment

Deployed with GNU Stow into the home directory:

```bash
stow -d . -t ~ shell-env
```

Files therefore appear in `$HOME` as symlinks back into the repo.

## Repo boundaries (important)

The user's dotfiles are split across **many separate git repositories**, most
stowed from `~/.STOW/<package>/`. A file visible in `$HOME` may belong to a
*sibling* repo (e.g. `~/.GIT/adamspiers.org/ssh`), not to this one. Before
editing or committing a file reached via a `$HOME` symlink, resolve it
(`realpath`) and confirm which repo owns it with `git rev-parse --show-toplevel`.
Commit each repo's changes separately.

## Conventions

- Respect `.editorconfig`. Never leave trailing whitespace on blank lines.
- Match the style of surrounding shell code.
- The default branch here is `master`.
- Use `git push origin HEAD` (never a bare `git push`) to avoid pushing a
  feature branch to the wrong upstream.

## Gotcha: Claude Code shell snapshots strip `_`-prefixed functions

Claude Code runs Bash tool commands through a captured shell *snapshot*
(`~/.claude/shell-snapshots/snapshot-*.sh`), not your live `.zshrc`. The
snapshot generator omits every function whose name begins with `_` (to skip
zsh's completion-system namespace). Private helper functions named with a
leading underscore (e.g. an old `_pre_ssh`) are therefore **absent** when the
Bash tool runs, which breaks any wrapper that calls them unconditionally.

When writing shell wrappers that call helper functions, guard the call so a
shell lacking the helper degrades gracefully, e.g.:

```zsh
whence -w helper >/dev/null && helper "$@"
```
