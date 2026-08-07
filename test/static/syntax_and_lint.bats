#!/usr/bin/env bats
# vim: set tabstop=2 shiftwidth=2 autoindent smartindent:

# TESTING.md ¶1: static checks, run first, on every shell file in the repo.

setup() {
	load '../test_helper/common'
	load '../test_helper/discover_files'
	load_bats_helpers
}

@test "bash -n passes on every shell file" {
	local file failed=0
	while IFS= read -r file; do
		if ! bash -n "${file}" 2>&1; then
			echo "SYNTAX ERROR: ${file}"
			failed=1
		fi
	done < <(mbe_all_shell_files)
	[ "${failed}" -eq 0 ]
}

@test "shellcheck -S error passes on every shell file" {
	if ! command -v shellcheck >/dev/null 2>&1; then
		skip "shellcheck not installed"
	fi
	local file failed=0
	while IFS= read -r file; do
		if ! shellcheck -S error "${file}"; then
			echo "SHELLCHECK ERROR: ${file}"
			failed=1
		fi
	done < <(mbe_all_shell_files)
	[ "${failed}" -eq 0 ]
}

@test "no module defines the same top-level function name twice in one file" {
	# Column-0 (unindented) definitions only -- this is what catches the
	# rtc-style bug (a whole second top-level function silently shadowing
	# the first). Indented "usage ()" helpers nested inside several
	# distinct outer functions (ant/eclipse/informix/java/maven/mongo) are
	# a different, legitimate idiom and must not trip this check.
	local file failed=0
	while IFS= read -r file; do
		local dupes
		dupes="$(grep -oE '^(function[[:space:]]+)?_?[A-Za-z_][A-Za-z0-9_]*[[:space:]]*\(\)' "${file}" \
			| sed -E 's/^(function[[:space:]]+)?//; s/[[:space:]]*\(\)$//' \
			| sort | uniq -d)"
		if [ -n "${dupes}" ]; then
			echo "DUPLICATE FUNCTION(S) in ${file}:"
			echo "${dupes}"
			failed=1
		fi
	done < <(mbe_all_module_names | while read -r m; do
		f="${MBE_REPO_ROOT}/modules/${m}/${m}"
		[ -f "${f}" ] && echo "${f}"
	done)
	[ "${failed}" -eq 0 ]
}

@test "every module with a non-mbe-only dependency activates it in _load" {
	# 'mbe' itself is bootstrapped directly in bashrc before any module's
	# _load ever runs, so __<name>_dependencies=( 'mbe' ) alone never needs
	# a real _mbe_activateModules call to be correct -- most single-
	# dependency modules are exactly this shape (see CLAUDE.md). The
	# historical bug class (found in rar/rtc/scite/vim/perl/git/mongo/utils)
	# was a REAL dependency (java, platform, homebrew, ...) declared but
	# never activated, so only flag arrays with more than just 'mbe'.
	local module failed=0
	while IFS= read -r module; do
		local file="${MBE_REPO_ROOT}/modules/${module}/${module}"
		[ -f "${file}" ] || continue
		local depsline
		depsline="$(grep "^__${module}_dependencies=" "${file}" || true)"
		[ -z "${depsline}" ] && continue
		if [[ "${depsline}" =~ ^__${module}_dependencies=\([[:space:]]*\'mbe\'[[:space:]]*\)$ ]]; then
			continue # mbe-only, always already active
		fi
		if ! grep -q '_mbe_activateModules[[:space:]]\+"\${__'"${module}"'_dependencies\[@\]}"' "${file}"; then
			echo "DECLARED BUT NOT ACTIVATED: ${module} (${depsline})"
			failed=1
		fi
	done < <(mbe_all_module_names)
	[ "${failed}" -eq 0 ]
}
