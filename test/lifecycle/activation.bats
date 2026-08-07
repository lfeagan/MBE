#!/usr/bin/env bats
# vim: set tabstop=2 shiftwidth=2 autoindent smartindent:

# TESTING.md ¶3: module lifecycle, activation.

setup() {
	load '../test_helper/common'
	load_bats_helpers
	mbe_bootstrap
}

# Note: this activates every module in one loop inside a single @test.
# bats installs a DEBUG trap that instruments every simple command executed
# inside a test body (its failure-line-attribution mechanism), which makes
# this noticeably slower (~1-2 min) than the same loop run standalone
# (~5s) -- expected, not a hang, and not worth restructuring around.
@test "every module in the repo activates standalone without error" {
	local module failed=0
	local out="${BATS_TEST_TMPDIR}/activate_out"
	while IFS= read -r module; do
		[ "${module}" == "mbe" ] && continue
		if ! _mbe_activateModules "${module}" >"${out}" 2>&1; then
			echo "FAILED: ${module}"
			cat "${out}"
			failed=1
		fi
	done < <(mbe_all_module_names)
	[ "${failed}" -eq 0 ]
}

@test "activating eclipse pulls in its full dependency chain" {
	_mbe_activateModules eclipse
	for dep in eclipse java platform utils mbe; do
		[ -n "${MODULES_ACTIVE_SET[${dep}]}" ]
	done
}

@test "function tracking attributes zero cross-contamination across a real dependency chain" {
	_mbe_activateModules eclipse

	for a in eclipse java platform utils; do
		for b in eclipse java platform utils; do
			[ "${a}" == "${b}" ] && continue
			local -A aset=( )
			local f
			for f in ${MBE_MODULE_FUNCS[${a}]}; do aset[$f]=1; done
			for f in ${MBE_MODULE_FUNCS[${b}]}; do
				if [ -n "${aset[$f]}" ]; then
					echo "CROSS-CONTAMINATION: ${f} claimed by both ${a} and ${b}"
					return 1
				fi
			done
		done
	done
}

@test "var tracking attributes zero cross-contamination across a real dependency chain, and never tracks PATH-family vars" {
	_mbe_activateModules eclipse

	for a in eclipse java platform utils; do
		for b in eclipse java platform utils; do
			[ "${a}" == "${b}" ] && continue
			local -A aset=( )
			local v
			for v in ${MBE_MODULE_VARS[${a}]}; do aset[$v]=1; done
			for v in ${MBE_MODULE_VARS[${b}]}; do
				if [ -n "${aset[$v]}" ]; then
					echo "CROSS-CONTAMINATION: ${v} claimed by both ${a} and ${b}"
					return 1
				fi
			done
		done
	done

	for m in eclipse java platform utils; do
		case " ${MBE_MODULE_VARS[$m]} " in
			*" PATH "*|*" LD_LIBRARY_PATH "*|*" MANPATH "*|*" INCLUDE "*)
				echo "${m} incorrectly tracks a PATH-family variable: ${MBE_MODULE_VARS[$m]}"
				return 1
				;;
		esac
	done
}

@test "_mbe_buildpath runs exactly once for a multi-level activation, not once per recursion level" {
	local counter_file="${BATS_TEST_TMPDIR}/buildpath_calls"
	: > "${counter_file}"
	_mbe_buildpath() { echo x >> "${counter_file}"; }

	_mbe_activateModules eclipse

	local calls
	calls="$(wc -l < "${counter_file}" | tr -d ' ')"
	[ "${calls}" -eq 1 ]
}

@test "resource (re-sourcing mbe) preserves MODULES_ACTIVE, MBE_MODULE_FUNCS, and MBE_MODULE_VARS" {
	_mbe_activateModules eclipse
	local before_active="${MODULES_ACTIVE[*]}"
	local before_funcs="${MBE_MODULE_FUNCS[eclipse]}"
	local before_vars="${MBE_MODULE_VARS[eclipse]}"

	source "${MODULES_DIR}/mbe/mbe"

	[ "${MODULES_ACTIVE[*]}" == "${before_active}" ]
	[ "${MBE_MODULE_FUNCS[eclipse]}" == "${before_funcs}" ]
	[ "${MBE_MODULE_VARS[eclipse]}" == "${before_vars}" ]
	declare -F _eclipse_load >/dev/null
}
