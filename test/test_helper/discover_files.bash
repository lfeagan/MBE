#!/bin/bash
# vim: set tabstop=2 shiftwidth=2 autoindent smartindent:

# Enumerates every shell file this repo ships, for the static-check sweep in
# TESTING.md ¶1. Two groups: files with a bash shebang (found dynamically,
# so a newly added module file is picked up with no list to maintain), plus
# a fixed list of top-level dotfiles that are sourced rather than executed
# (so carry no shebang, or a misleading one) -- mbe_completion declares
# #!/bin/sh but uses bash-only array syntax, since it's always sourced under
# bash, never actually run under sh.
mbe_all_shell_files() {
	local root="${MBE_REPO_ROOT}"
	grep -rl -E '^#!(/bin/bash|/usr/bin/env bash)' \
		"${root}/modules" "${root}/bashrc" "${root}/install" 2>/dev/null
	printf '%s\n' \
		"${root}/bash_aliases" \
		"${root}/bash_profile" \
		"${root}/mbe_completion"
}
