#!/bin/sh
# mbe completions for bash shell.
#

_mbe_complete()
{
#	local cur prev opts base module
	COMPREPLY=( )
	cur="${COMP_WORDS[COMP_CWORD]}"
	prev="${COMP_WORDS[COMP_CWORD-1]}"
	opts="list load unload version `mbe_listLoadedModules`"

	# Determine if the first argument is a loaded module
	# and define module to be the module's name
	if [ "${COMP_CWORD}" -gt 0 ]; then
		module="${COMP_WORDS[1]}"
		if [ -z "${module}" ]; then
			module=""
		else
			mbe_isModuleLoaded "${module}"
			retval=$?
			if [ $retval -ne 1 ]; then
				module=""
			fi
		fi
	fi

	if [ $COMP_CWORD -eq "1" ]; then
		COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
		return 0
	elif [ -z "${module}" ]; then
		case "${prev}" in
			list)
				COMPREPLY=( loaded all )
				return 0
				;;
			load)
				local loaded=`mbe_listAllModules`
				COMPREPLY=( $(compgen -W "${loaded}" -- ${cur})  )
				return 0
				;;
			unload)
				local loaded=`mbe_listLoadedModules`
				COMPREPLY=( $(compgen -W "${loaded}" -- ${cur})  )
				return 0
				;;
		esac
		return 0
	else
		_${module}_complete
		return 0
	fi

	if [ -z "${cur}" ]; then
		COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
		return 0
	else
		local loaded=`mbe_listLoadedModules`
		_eclipse_complete
	fi

	COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
	return 0
}
complete -F _mbe_complete mbe

_module_complete()
{
	echo foo
}

#_mbe_listAllCommands()
#{
#
#	if [ $COMP_CWORD -eq "1" ]
#	then
#		_mbe_compFirstWord
#	else
#		COMPREPLY=( )
#		return 0
#	fi
#}

#_mbe_listLoadedModules()
#{
#	local cur prev opts
#	COMPREPLY=( )
#	cur="${COMP_WORDS[COMP_CWORD]}"
#	prev="${COMP_WORDS[COMP_CWORD-1]}"
#	opts="--list --load --unload --version"
#	
#	if [[ ${cur} == -* ]] ; then
#		COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
#		return 0
#	fi
#}
#complete -F _mbe_listAllCommands mbe

