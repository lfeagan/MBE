#!/bin/bash
# vim: set tabstop=2 shiftwidth=2 autoindent smartindent:

#------------------------------------------------------------------------------
# Copyright 2009 Lance W. Feagan
#
# Licensed under the Apache License, Version 2.0 (the "License"); 
# you may not use this file except in compliance with the License. 
# You may obtain a copy of the License at 
#
#	http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software 
# distributed under the License is distributed on an "AS IS" BASIS, 
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. 
# See the License for the specific language governing permissions and 
# limitations under the License. 
#------------------------------------------------------------------------------

# There are 3 different types of shells in bash: the login shell, normal shell
# and interactive shell. Login shells read ~/.profile and interactive shells
# read ~/.bashrc; in our setup, /etc/profile sources ~/.bashrc - thus all
# settings made here will also take effect in a login shell.
#
# NOTE: It is recommended to make language settings in ~/.profile rather than
# here, since multilingual X sessions would not work properly if LANG is over-
# ridden in every subshell.

#export _DEBUG="on"

# If not running interactively, don't do anything
# If MBE_NONINTERACTIVE is set and is non-zero, we still load MBE for use in non-interactive contexts
if [[ ( -z "$PS1" ) && ( ( -z $MBE_NONINTERACTIVE ) || ( $MBE_NONINTERACTIVE -eq 0 ) ) ]]
then
	return
fi

##################################
# ###### LOAD PREFERENCES ###### #
##################################
export MBE_DIR="${HOME}/.mbe"
export MODULES_DIR="${MBE_DIR}/modules"
export MODULES_LOAD=("mbe" "platform" "utils" "colors" "prompt" "eclipse" "java" "homebin" "icscope2" "netclient" "opengl" "openwin" "rar" "sbin" "scite" "sunstudio" "userid" "usrlocalbin" "vim" "maven" "ifxtools" )
# Loaded modules are stored in MODULES_LOADED

source "${MODULES_DIR}/mbe/mbe.conf"

##################################
# ##### MANUAL MODULE LOAD ##### #
##################################
# Define the storage location for the modules
# export MODULES_DIR="${HOME}/.mbe/modules"
# Specify the modules to be loaded
# export MODULES_LOAD=("mbe" "platform" )

# Bootstrap by manually loading the mbe module, the others can be done automatically
. "${MODULES_DIR}/mbe/mbe"
mbe_load
# Load the modules specified in the preferences file
mbe_loadModules "${MODULES_LOAD[@]}"

#########################
# ###### GENERAL ###### #
#########################

export RETVAL

localhostIsSecure=0
localhostIsShared=0
if [ -z "${SECURE_HOSTS[*]}" ]; then
	SECURE_HOSTS=( )
fi
if [ -z "${SHARED_HOSTS[*]}" ]; then
	SHARED_HOSTS=( )
fi

isLocalhostSecure ()
{
	for host in "${SECURE_HOSTS[@]}"; do
		if [[ "$host" == "$HOSTNAME" || "$host" == "localhost" ]]; then
			localhostIsSecure=1
			break
		fi
	done
	return 1;
}
isLocalhostShared ()
{
	for host in "${SHARED_HOSTS[@]}"; do
	if [[ "$host" == "$HOSTNAME" || "$host" == "localhost" ]]; then
		localhostIsShared=1
		break
	fi
	done
	return 1;
}

isLocalhostSecure
isLocalhostShared

# Secure development systems are the most permissive umask, typically 0x000
# Thus why we check it first. The ideal strategy may be to sort the list, bash
# associative arrays, introduced in 4.0, would make this easier.
if [ $localhostIsSecure -eq 1 ]; then
	umask "${SECURE_HOSTS_UMASK}"
else 
	# umask for shared, but safe, systems
	if [ $localhostIsShared -eq 1 ]; then
		umask "${SHARED_HOSTS_UMASK}"
	else
		# umask for public/shared systems
		umask "${INSECURE_HOSTS_UMASK}"
	fi
fi

#####################################
# ##### ENVIRONMENT VARIABLES ##### #
#####################################

std_bin_paths=("/bin" "/usr/bin" "/usr/local/bin" "/sbin" "/usr/sbin" "/usr/local/sbin")
#std_bin_paths_arg=`echo ${std_bin_paths[@]}`

# Limit core dumps to zero size (e.g. do not allow core dumps)
ulimit -c 0

# If TERM=vt100, even if terminal reports support for color (COLORTERM=1), vim will fail to use colors but will work if TERM=xterm.
if [[ "$COLORTERM" -eq 1 ]]; then
	if [[ "$TERM" != 'xterm' ]]; then
		declare -x TERM='xterm'
	fi
fi

# dircolors works much better than the antiquated exports used below
if [ -f /usr/bin/dircolors ]; then
	eval $(dircolors -b)
else
	export LS_COLORS='no=01;37:fi=01;37:di=01;34:ln=01;36:pi=01;32:so=01;35:do=01;35:bd=01;33:cd=01;33:ex=01;31:mi=00;37:or=00;36:'
fi

# Pager
if [ -z "${USER_PAGERS[*]}" ]; then
	mbe_pager_choices=("less" "more")
else
	mbe_pager_choices=( $(echo "${USER_PAGERS[*]}") )
fi
mbe_envpathsearch PAGER ${#USER_PAGERS[@]} `echo ${mbe_pager_choices[@]} ${std_bin_paths[@]}`
[ -n "$RETVAL" ] && $(echo $RETVAL)

# Editors
if [ -z "${USER_EDITORS[*]}" ]; then
	mbe_editor_choices=("vim" "vi" "emacs")
else
	mbe_editor_choices=( $(echo "${USER_EDITORS[*]}") )
fi
mbe_envpathsearch EDITOR ${#USER_EDITORS[@]} `echo ${mbe_editor_choices[@]} ${std_bin_paths[@]}`
[ -n "$RETVAL" ] && $(echo $RETVAL)
export CVSEDITOR="${EDITOR}"
export FCEDIT="${EDITOR}"
export SVN_EDITOR="${EDITOR}"
export VISUAL="${EDITOR}"

# Maximum number of lines that can be written to the history file
HISTFILESIZE=2000
# Number of lines to be saved by this bash shell at exit
HISTSIZE=2000
# Ignores duplicate lines next to eachother and ignores a line with a leading space
# e.g. ignoredups and ignorespace combined
HISTCONTROL=ignoreboth
# Command patterns that are to be excluded from the history
HISTIGNORE="ls:bg:fg:exit"
# HISTIGNORE supports regexes, but Ubuntu seemed to take exception to this. So, [bf]g is now expanded to bg:fg
declare -x HISTFILESIZE HISTSIZE HISTCONTROL HISTIGNORE

################################
# ##### SHELL VARIABLES ###### #
################################

#set -o noclobber # Shell redirection should not clobber (over-write) existing files.
set +o noclobber # Shell redirection is allowed to clobber (over-write) existing files.
set +o physical # PWD follows the logical structure with regards to symbolic links. For example, if physical is enabled when cd'ing to a symlinked-directory, PWD will be the disambugation of as many links as is necessary to resolve to a physical location.
set -o notify # Enable asynchronous notification of background job completion.

# Options that work with bash versions > 2.0
shopt -s cdspell # Correct minor spelling errors automatically
shopt -s extglob # Enable extended pattern matching
shopt -s dotglob # Include filenames beginning with a '.' in the results of filename expansion
shopt -s cmdhist # Keep a multi-line command together in history
shopt -s lithist # Multi-line commands saved to history with embedded newlines rather than using semicolon separators where possible.
shopt -s execfail # Make it so that failed `exec' commands don't flush this shell.
shopt -s checkhash # Check that a command found in the hash table exists before trying to execute it. If a hashed command no longer exists, a normal path search is performed.
shopt -s histappend # If  set,  the  history list is appended to the file named by the value of the HISTFILE variable when the shell exits, rather than overwriting the file.
shopt -s histverify # If set, and readline is being used, the results of history substitution are not immediately passed to the shell parser.  Instead, the resulting line is  loaded  into  the readline editing buffer, allowing further modification.
shopt -s histreedit # Allow re-editing of a failed history substitution
shopt -s promptvars # Prompt strings undergo variable and parameter expansion after being expanded.
shopt -s cdable_vars # An argument to the cd builting command that is not a directory is assumed to be the name of a variable whose value is the directory to change to.
shopt -s checkwinsize # Check the window size after each command and, if necessary, update the valeus of LINES and COLUMNS.
shopt -s hostcomplete # Perform hostname completion when a word containing '@' is being completed.
shopt -s expand_aliases # Enable alias expansion.
shopt -s interactive_comments # Allow a word beginning with '#' to cause that word and all remaining characters on that line to be ignored in an interactive shell.
#shopt -s no_empty_cmd_completion # Do not attempt to search the PATH for possible completions when completion is attempted on an empty line.
#shopt -s nocaseglob # Match filenames in a case-insensitive fashion when performing filename expansion.

# Options that work with bash version > 3.0
if [ "${BASH_VERSINFO[0]}" -ge 3 ]; then
	#echo "Bash version 3.x options enabled"
	shopt -s progcomp # Enable programmable completion facilities.
fi

###########################
# ##### COMPLETIONS ##### #
###########################

if [ "${BASH_VERSINFO[0]}" -ge 3 ]; then
	complete -A setopt set
	complete -A user groups id
	complete -A binding bind
	complete -A helptopic help
	complete -A alias {,un}alias
	complete -A signal -P '-' kill
	complete -A stopped -P '%' fg bg
	complete -A job -P '%' jobs disown
	complete -A variable readonly unset
	complete -A file -A directory ln chmod
	complete -A user -A hostname finger pinky
	complete -A directory find cd pushd {mk,rm}dir
	complete -A file -A directory -A user chown
	complete -A file -A directory -A group chgrp
	complete -o default -W 'Makefile' -P '-o ' qmake
	complete -A command man which whatis whereis sudo info apropos
	complete -A file {,z}cat pico nano vi {,{,r}g,e,r}vi{m,ew} vimdiff elvis emacs {,r}ed e{,x} joe jstar jmacs rjoe jpico {,z}less {,z}more p{,g}
fi

############################
# ##### KEY BINDINGS ##### #
############################

bind '"\C-t": possible-completions' # replaces 'transpose-chars'
bind '"\M-t": menu-complete'        # replaces 'transpose-words'

# Source global definitions
#if [ -f /etc/bashrc ]; then
#	. /etc/bashrc
#fi

# User alias specifications
test -s ~/.bash_aliases && . ~/.bash_aliases

# User-specific bash files are sourced last so that they can override anything
#test -s ~/.bash_${USER} && ~/.bash_${USER}
if [ -f "${HOME}/.bash_${USER}" ]; then
	source "${HOME}/.bash_${USER}"
fi

# Sources important shell files again. Used when changing users and wanting to source files or when making frequent changes to installed bash files.
resource ()
{
	#mbe_reloadModules
	source ${HOME}/.bashrc; 
	source ${HOME}/.bash_aliases;
}

#######################
# ##### THE END ##### #
#######################
