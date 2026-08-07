#!/usr/bin/env bats
# vim: set tabstop=2 shiftwidth=2 autoindent smartindent:

# TESTING.md ¶4: module lifecycle, deactivation. The full-sweep leak test
# below is called out in TESTING.md as the single highest-value test in
# the whole document -- it caught nine modules with drifted
# __<name>_functions arrays, a _mbe_buildpath recursion bug, and a
# java/sdkman JAVA_HOME misattribution bug, all in one run.

setup() {
	load '../test_helper/common'
	load_bats_helpers
	mbe_bootstrap
}

@test "full sweep: activate then deactivate every module, zero leaked functions or vars" {
	local names=( )
	while IFS= read -r module; do
		[ "${module}" == "mbe" ] && continue
		names+=( "${module}" )
	done < <(mbe_all_module_names)

	_mbe_activateModules "${names[@]}"

	local -A snapfuncs snapvars
	local n
	for n in "${names[@]}"; do
		snapfuncs[${n}]="${MBE_MODULE_FUNCS[${n}]}"
		snapvars[${n}]="${MBE_MODULE_VARS[${n}]}"
	done

	local failed=0
	for n in "${names[@]}"; do
		_mbe_deactivateModules -y "${n}" >/dev/null 2>&1

		local f
		for f in ${snapfuncs[${n}]}; do
			if declare -F "${f}" >/dev/null 2>&1; then
				echo "LEAK func: ${n} -> ${f}"
				failed=1
			fi
		done

		local v
		for v in ${snapvars[${n}]}; do
			if [ -n "${!v+set}" ]; then
				echo "LEAK var: ${n} -> ${v}"
				failed=1
			fi
		done
	done

	# mbe is bootstrapped directly (see test_helper/common.bash's
	# mbe_bootstrap) and never goes through _mbe_deactivateModules, so it's
	# the one expected survivor.
	if [ "${MODULES_ACTIVE[*]}" != "mbe" ]; then
		echo "MODULES_ACTIVE not reduced to just mbe: ${MODULES_ACTIVE[*]}"
		failed=1
	fi

	[ "${failed}" -eq 0 ]
}

@test "cascade-deactivate: an active dependent is warned about and actually deactivated" {
	# Not `run` -- run executes in a subshell, so MODULES_ACTIVE_SET
	# mutations inside _mbe_deactivateModules would never be visible back
	# in this test (found live: the first version of this test used `run`
	# and both membership assertions below failed even though the function
	# worked correctly). Capture output to a file instead, in-process.
	_mbe_activateModules java maven
	local out="${BATS_TEST_TMPDIR}/cascade_out"
	_mbe_deactivateModules -y java >"${out}" 2>&1
	grep -q "maven" "${out}"
	[ -z "${MODULES_ACTIVE_SET[java]+set}" ]
	[ -z "${MODULES_ACTIVE_SET[maven]+set}" ]
}

@test "no dependents: deactivation is silent (no cascade prompt/output) and immediate" {
	_mbe_activateModules colors
	local out="${BATS_TEST_TMPDIR}/no_dependents_out"
	_mbe_deactivateModules -y colors >"${out}" 2>&1
	! grep -q "depend on" "${out}"
	[ -z "${MODULES_ACTIVE_SET[colors]+set}" ]
}

@test "cascade-deactivate confirmation prompt: n aborts, y proceeds" {
	_mbe_activateModules java maven
	local out="${BATS_TEST_TMPDIR}/prompt_out"

	# Process substitution for stdin, NOT `echo ... | _mbe_deactivateModules`:
	# a pipe runs its last command in a subshell (no `shopt -s lastpipe`
	# here), so MODULES_ACTIVE_SET mutations inside the function would never
	# be visible back in this test -- found live: the pipe form reported
	# rc=0 and the right stdout on both branches, but neither assertion
	# below ever passed, since every mutation was happening in a throwaway
	# subshell. This is the same class of pitfall TESTING.md ¶8 already
	# warns about for piped stdin, just via a pipe's implicit subshell
	# rather than redirecting a whole script's stdin.
	#
	# _mbe_deactivateModules intentionally returns 1 on the "n" (aborted)
	# path -- `|| true` so that expected nonzero doesn't trip set -e.
	_mbe_deactivateModules java >"${out}" 2>&1 < <(echo "n") || true
	grep -q "Aborted" "${out}"
	[ -n "${MODULES_ACTIVE_SET[java]+set}" ]
	[ -n "${MODULES_ACTIVE_SET[maven]+set}" ]

	_mbe_deactivateModules java >"${out}" 2>&1 < <(echo "y")
	[ -z "${MODULES_ACTIVE_SET[java]+set}" ]
	[ -z "${MODULES_ACTIVE_SET[maven]+set}" ]
}
