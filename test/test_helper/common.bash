#!/bin/bash
# vim: set tabstop=2 shiftwidth=2 autoindent smartindent:

# Shared setup for MBE bats tests. Loaded via `load '../test_helper/common'`
# (bats resolves relative to the test file's directory).

MBE_REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

load_bats_helpers() {
	load "${MBE_REPO_ROOT}/test/test_helper/bats-support/load"
	load "${MBE_REPO_ROOT}/test/test_helper/bats-assert/load"
	load "${MBE_REPO_ROOT}/test/test_helper/bats-file/load"
}

# Lists every module directory name under modules/, in the real repo --
# mirrors _mbe_listAllModules's own modules=( "${MODULES_DIR}"/* ) shape
# without requiring mbe itself to be sourced yet.
mbe_all_module_names() {
	local m
	for m in "${MBE_REPO_ROOT}"/modules/*/; do
		basename "${m%/}"
	done
}

# Sources mbe itself and calls _mbe_load in the current shell (bats runs
# each @test in its own forked subshell, so this state never leaks between
# tests -- see TESTING.md ¶8 on why isolation matters). Mirrors bashrc's own
# bootstrap exactly: it manually sources+_mbe_loads mbe (since _mbe_load
# itself isn't defined until mbe is sourced), then activates "mbe" through
# _mbe_activateModules as the first entry of MODULES_INIT -- that second
# step is what registers mbe in MODULES_ACTIVE_SET. Skipping it here would
# make mbe look "not yet active" to any later _mbe_activateModules call
# that (transitively) depends on it, causing mbe/mbe to be re-sourced --
# which clobbers any test-local override of an mbe/mbe-defined function
# like _mbe_buildpath.
mbe_bootstrap() {
	MODULES_DIR="${MBE_REPO_ROOT}/modules"
	MBE_DIR="${BATS_TEST_TMPDIR}/.mbe"
	mkdir -p "${MBE_DIR}"
	# shellcheck source=/dev/null
	source "${MODULES_DIR}/mbe/mbe"
	_mbe_load
	_mbe_activateModules mbe
}
