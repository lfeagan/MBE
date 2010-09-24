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

#######################
# ##### ALIASES ##### #
#######################

#alias more=less
 
alias md='mkdir'
alias rd='rmdir'
alias +='pushd .'
alias pu='pushd'
alias po='popd'
alias ugly='nice -n -200'
alias bz='bzip2'
alias wget='wget -c --tries=100'
#alias which='alias | /usr/bin/which --tty-only --read-alias --show-dot --show-tilde'


################################
# ##### SIMPLE FUNCTIONS ##### #
################################

acm () { autoconf; automake; }
mcm () { make clean; make; }

rmd () { rm -fr $@; }

x () { exit    $@; }
z () { suspend $@; }
j () { jobs -l $@; }

osr () { shutdown -r now; }
osh () { shutdown -h now; }

p () { ${PAGER}  $@; }
e () { ${EDITOR} $@; }

c () { clear; }
h () { history $@; }
hc () { history -c; }
hcc () { hc;c; }

cx () { hc;x; }

function .. () { cd ..; }
function ... () { cd ../..; }
function .... () { cd ../../..; }

# For linux, always use color with 'ls'
# For solaris et al, do not use color as it is usually unsupported
if [[ "$OSTYPE" == linux* ]]; then
  alias ls='ls --color=auto'
fi

addkey () { ssh-agent sh -c 'ssh-add < /dev/null && bash'; }
xtermb () { xterm -fg 'white' -bg 'black'; }
ew () { ${EDITOR} `which $@`; }

# Modified listing commands
#ll () { ls --color=auto -FAql $@; }
#lf () { ls --color=auto -FAq  $@; }
function ll () { [[ "$OSTYPE" == linux* ]] && ls -FAql $@ || ls -FAl $@; }
lf () { [[ "$OSTYPE" == linux* ]] && ls -FAq $@ || ls -FA $@; }
function la () { ls -A $@; }
function l () { ls -CF $@; }
l. () { ls -d .* $@; } 
lk () { ls -lSrk $@; }
lh () { ls -lSrh $@; }
lt () { ls -ltr $@; }
cls () { clear; ls $@; }
cll () { clear; ll $@; }
function dir () { ls --color=auto --format=vertical; }
vdir () { ls --color=auto --format=long; }

# Save the real which for a rainy day
if [ -z "$whichbin" ]; then
	whichbin="$(which which)"
fi
ewhich ()
{
	if [[ "$OSTYPE" == linux* ]]; then
		if [[ "$OSDISTRIBUTOR" == "Ubuntu" ]]; then
			$(echo $whichbin) $@
		else
			(alias; declare -f) | $(echo $whichbin) --tty-only --read-alias --read-functions --show-tilde --show-dot $@
		fi
	else
		$(echo $whichbin) $@
	fi
}

#whichcd ()
#{
#	local usage="Usage: whichcd <executable file>"
#	if [ -n "$1" ]; then
#		local dir="$(which ${1} 2> /dev/null)"
#		dir="${dir%/*}"
#		# if which's return value is zero
#		if [[ -n "$dir" ]]; then
#			cd "$dir"
#		else
#			echo -e "Command '${1}' not found"
#		fi
#	else
#		echo "$usage"
#	fi
#}
#
whichvi ()
{
	local usage="Usage: whichvi <executable file>"
	if [ -n "$1" ]; then
		local path="$($whichbin $1)"
		DEBUG echo "path=$path"
		if [[ -n "$path" ]]; then
			vi $path
		else
			echo -e "Error: Command '${1} not found"
		fi
	else
		echo "$usage"
	fi
}

filereplace ()
{
	#------------------------------------------------------------------------------
	# Author: Lance Feagan
	# Date: 2008-10-03
	# Description: Finds all instances of a source file under a directory and
	#   replaces with a user-specified version.
	#------------------------------------------------------------------------------

  # Define usage message
  usage ()
  {
    echo "Usage: filereplace -s <source file> -t <target directory> [-b] [-d] [-h]"
		echo "  Arguments:"
		echo "    -s <source file> The file to be copied from"
		echo "    -t <target directory> The directory containing file(s) to be over-written"
		echo "    -b Create backup copies of the originals"
		#echo "    -d Print debugging information"
  }

	# Process Arguments
  # parse arguments with getopts
  # reset getopts state variables
	unset source
	unset target
	unset sourcedir
	unset sourcefile
	unset backups
  unset print_usage
	#local _DEBUG_OLD="$_DEBUG"
  while getopts "s:t:bdh" option
  do
    case $option in
      s  ) source=$OPTARG;;
      t  ) targetdir=$OPTARG;;
			b  ) backups="1";;
			#d  ) _DEBUG="1";;
      h  ) print_usage="1";;
      \? ) print_usage="1";;
      *  ) print_usage="1";;
    esac
  done
  OPTIND=1 # Reset OPTIND

	if [[ ( -z "${source}" ) || ( -z "${targetdir}" ) ]]; then
		echo "ERROR: Both source and target must be specified"
		print_usage="1"
	fi

	# Display usage message and return control to invoking shell
  if [[ "$print_usage" == "1" ]]; then
    usage
    return 0
  fi

	# Verify reasonableness of user-specified source and target
	# Source must be a readable file
	if [[ ! ( -f "${source}" ) || ! ( -r "${source}" ) ]]; then
		echo "ERROR: Source ${source} is non-file or is unreadable"
		print_usage="1"
	fi
	# Target must be a directory
	if [[ ! ( -d "${targetdir}" ) ]]; then
		echo "ERROR: Target ${target} is non-directory or does not exist"
		print_usage="1"
	fi

	# Break apart source into directory and file components
	sourcedir="${source%/*}"
	sourcefile="${source##*/}"

	DEBUG echo -e "Target directory: \"${targetdir}\""
	DEBUG echo "Searching for file: ${sourcefile}"
	targetfiles=( $(find ${targetdir} -name ${sourcefile} -printf "%p\n" ) )
	DEBUG echo "targetfiles=${targetfiles[@]}"
	for targetfile in "${targetfiles[@]}"; do
		# Do backup creation before over-writing
		# !!! WARNING !!!
		# Using mv for the backup as find has already identified files to be replaced
		# This improves performance and reduces fragmentation but creates inherent risk
		# Be cautious if you consider changing this strategy
		if [[ "${backups}" == "1" ]]; then
			DEBUG echo "mv ${targetfile} ${targetfile}.backup"
			mv "${targetfile}" "${targetfile}.backup"
		fi
		DEBUG echo "cp ${source} ${targetfile}"
		cp "${sourcefile}" "${targetfile}"
	done
}

# Mount commands
# FUSE/SSHFS
declare -x SSHFS_LOCALDIR="nfs-homedir"
msshfs ()
{
 # Mounts your home directory from a remote system in the folder ${SSHFS_LOCALDIR}

 # Check if there was an option passed...
 if [ -z "$1" ]; then
  remotehost="raka"
 else
  remotehost="$1"
 fi

 # Implement some simple hostname "aliases" to resolve ".lenexa.ibm.com" hosts when used from home
 lenexa_hosts=(lfeagan2 raka)

 # Iterate over all array elements, if we find that remotehost is in the array, append ".lenexa.ibm.com" to the remotehost specification
 for i in "${lenexa_hosts[@]}"; do
  if [ "$remotehost" == "$i" ]; then
   echo -ne "Found lenexa_hosts match for ${remotehost}, "
   remotehost="${remotehost}.lenexa.ibm.com"
   echo -ne "appending \".lenexa.ibm.com\" to \$remotehost\n"
   break
  fi
 done

 # TODO
 # Think about how to appropriately add in a new feature to allow mounting to either
 # (a) a new folder based on the hostname being connected to, or
 # (b) checking if there has already been a mount to ssh-home, and if there has then mount to ssh-home[0-9]
 # Lastly, it might be nice to make it easy to mount something other than your home directly, such as the root of the remote filesystem. This could be implemented as a simple option, perhaps using a -r="/remote/path/to/mount" option.
 # The above items 

 sshfs ${remotehost}: ${HOME}/${SSHFS_LOCALDIR};
}
umsshfs ()
{
	fusermount -u ${HOME}/${SSHFS_LOCALDIR};
}
# GSA (Austin)
cdgsa () { pushd .; cd /gsa/ausgsa/home/$(echo ${USER} | cut -c 1)/$(echo ${USER} | cut -c 2)/${USER}; }
# Floppy
mfloppy () { mount /dev/fd0 /mnt/floppy; }
umfloppy () { umount /mnt/floppy; }
# ISO9660 DVD
mdvd () { mount -t iso9660 -o ro /dev/dvd /mnt/dvd; }
umdvd () { umount /mnt/dvd; }
# ISO9660 CDROM
mcdrom () { mount -t iso9660 -o ro /dev/cdrom /mnt/cdrom; }
umcdrom () { umount /mnt/cdrom; }
# ISO9660 File Loopback
miso () { mount -t iso9660 -o ro,loop $@ /mnt/iso; }
umiso () { umount /mnt/iso; }

ff () { find . -name $@ -print; }

psa () { ps aux $@; }
psu () { ps  ux $@; }

lpsa () { ps aux $@ | p; }
lpsu () { ps  ux $@ | p; }

dub () { du -scb $@; }
duk () { du -sck $@; }
duks () { duk $@ 2>/dev/null | sort -n -k1,1; }
dum () { du -scm $@; }
dums () { du -scm $@ 2>/dev/null | sort -n -k1,1; }
duh () { du -sch $@; }
#duh () { dh -h --max-depth=1 $@; }

dfk () { df -PTak $@; }
dfm () { df -PTam $@; }
dfh () { df -PTah $@; }
dfi () { df -PTai $@; }
dflocal ()
{
	if [[ "$OSTYPE" == solaris ]]; then
		df -F ufs -o i
	else
		df -l
	fi
}

dmsg () { dmesg | p; }

# Moved 'resource' to bashrc so it can be called more easily
#resource         { source ${HOME}/.bashrc; source ${HOME}/.bash_aliases; }

kernfs () { p /proc/filesystems; }
shells () { p /etc/shells; }

lfstab () { p /etc/fstab; }
lxconf () { p /etc/X11/xorg.conf; }

if [ "`${IDPROG_USERID}`" -eq 0 ]
then
    efstab () { e /etc/fstab; }
    exconf () { e /etc/X11/xorg.conf; }
    txconf () { X -probeonly; }
fi

startvnc ()
{
	vncserver -depth 24 -geometry 1280x800 $@;
}

##############################
# ##### LONG FUNCTIONS ##### #
##############################

# Recursively retrieves the entire contents of the remote directory into a 
# similiarly named local directory, without all of the usual wget path trash.
wget-dir()
{
  #OPTARGS="--continue --tries=100 --recursive --level=inf --no-parent --page-requisites --no-host-directories"
  OPTARGS="--continue --tries=100 --recursive --level=inf --no-parent --no-directories"
  # if no arguments are given, print out the usage
  if [[ ( "$#" < 1) || ( "$#" > 2 ) ]]
  then
    echo "Usage: wget-dir <address> [<filename extension>]"
  else
    # if the second argument does not exist, simply retrieve all files in from the address listed
    if [ -z "$2" ]
    then
      wget $OPTARGS $1
    else
      wget $OPTARGS --ignore-case -A $2 $1
    fi
  fi
  # wget -r -l1 --no-parent -A.rpm http://linuxsrv1.zurich.ibm.com/linux/updates/yum/SLED/10/i386/hannover/
}

# Crawls the file system looking for large files to find candidates for deletion
# when a system is needing more free disk space.
# Inspired by problems with Chris Trotter's box mp-iperf
find-large ()
{
  # reference usage for finding large files 
  # find /var -type f -size +2000k -exec ls -l {} \; | sort -n -k 5,5

  # usage message printed to help users
  usage="Usage: find-large -p <path to search under> -s <minimum_size>"

  # When used as a function, do not call exit as it will exit the shell instead
  OPTERROR=33

  if [ -z $1 ] # Exit and complain if no argument(s) given.
  then
   echo $usage
   #exit $OPTERROR
  else
   # parse arguments with getopts
   while getopts ":p:s:" option
   do
    case $option in
     p  ) search_path=$OPTARG;;
     s  ) min_size=$OPTARG;;
     h  ) echo $usage
          return;;
     \? ) echo $usage
          return;;
     *  ) echo $usage
          return;;
    esac
   done
   # reset OPTIND to 1
   OPTIND=1

   shift $(($OPTIND - 1))
   # Decrements the argument pointer
   # so it points to next argument.

   echo search_path = "$search_path" 
   echo min_size = "$min_size"

   find "$search_path" -type f -size +"$min_size" -exec ls -l '{}' \; | sort -n -k5,1 | awk '{print $5 ": " $9 }'
  fi
 echo "Search complete"
}

##############################################
# ##### APPLICATION-SPECIFIC FUNCTIONS ##### #
##############################################
searchpath ()
{
 # Copy PATH so we can strip off elements from it
 path=$PATH
 while [ $path ]; do
  ls "${path%%:*}\n"

  # Delete the first element from path
  path="${path#*:}"
 done

 return ""
}
