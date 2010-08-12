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

############################################################
# Bash Module: platform
# Description: 
#  Configures the functions for identification of the CPU 
#  architecture, operating system kernel name, and 
#  kernel bits. In other words, the platform. Bash defines
#  three platform variables, MACHTYPE, OSTYPE, and HOSTTYPE,
#  but output of these varies on Linux with the distro.
#  Consequently, uname and other tools are used in
#  an attempt to create a more portable concept of
#  platform naming.
# Exports: KERNELNAME, KERNELBITS, CPUTYPE,
#   TOOLSPATH, TOOLSPATH32, TOOLSPATHGENERIC,
#   BSDARGS
# 
############################################################

platform_dependencies=( 'mbe' )
platform_functions=( 'platform_load' 'platform_unload' 'platform_setpath' \
		'platform_config' 'platform_platformpath' 'platform_toolspath' 'platform_desc'
		'cdtools' 'cdtools32' 'cdtoolsgeneric' )

platform_load ()
{
	local module="platform"
	# Load preferences file
	#source "${MODULES_DIR}/${module}/${module}.conf"
	# Define exports that cannot change after module load
	platform_config
	platform_platformpath
}

platform_unload ()
{
	local module="platform"
	local func
	for func in "${platform_functions[@]}"; do
		unset "${func}"
	done
	return 0
}

platform_setpath ()
{
	local module="platform"
	platform_toolspath
	platform_distributor
}

platform_isValidPlatform ()
{
	# KERNELNAME; KERNELBITS; CPUTYPE
	# AIX;        32,64;      powerpc
	# HP-UX;      32,64; 
	# IRIX64;     64;         mips
	# Darwin;     64;         x86_64
	# Linux;      32;         i?86,ppc32,ppc64
	# Linux;      64;         x86_64,ppc64
	# SunOS;      32,64;      i686,sparc
	# OSF1;       64;         alpha

	if [[ "$KERNELNAME" == "AIX" && ("$KERNELBITS" == 32 || "$KERNELBITS" == 64) && "$CPUTYPE" == "powerpc" ]]; then
		return 1
	elif [[ "$KERNELNAME" == "HP-UX" && (("$KERNELBITS" == 32 || "$KERNELBITS" == 64) && "$CPUTYPE" == "pa") || ("$KERNELBITS" == 64 && "$CPUTYPE" == "ia64") ]]; then
		return 1
	elif [[ "$KERNELNAME" == "IRIX64" && ("$KERNELBITS" == 32 || "$KERNELBITS" == 64) && "$CPUTYPE" == "mips" ]]; then
		return 1
	elif [[ "$KERNELNAME" == "Darwin" && "$KERNELBITS" == 64 && "$CPUTYPE" == "x86_64" ]]; then
		return 1
	elif [[ "$KERNELNAME" == "Linux" && ("$KERNELBITS" == 32 && ("$CPUTYPE" == i?86 || "$CPUTYPE" == ppc*)) || ("$KERNELBITS" == 64 && ("$CPUTYPE" == "x86_64" || "$CPUTYPE" == "ppc64")) ]]; then
		return 1
	elif [[ "$KERNELNAME" == "SunOS" && ("$KERNELBITS" == 32 || "$KERNELBITS" == 64) && ("$CPUTYPE" == "sparc" || "$CPUTYPE" == "i686") ]]; then
		return 1
	elif [[ "$KERNELNAME" == "OSF1" && "$KERNELBITS" == 64 && "$CPUTYPE" == "alpha" ]]; then
		return 1
	else
		echo "invalid"
		return 0
	fi
}

platform_mkdirs ()
{
	local PLATFORM_KERNELNAME=( "AIX" "HP-UX" "IRIX64" "Darwin" "Linux" "SunOS" "OSF1" )
	local PLATFORM_AIX_KERNELBITS=( "32" "64" )
	local PLATFORM_AIX_32_CPUTYPE=( "powerpc" )
	local PLATFORM_AIX_64_CPUTYPE=( "powerpc" )
	local PLATFORM_HPUX_KERNELBITS=( "32" "64" )
	local PLATFORM_HPUX_32_CPUTYPE=( "pa" )
	local PLATFORM_HPUX_64_CPUTYPE=( "pa" "ia64" )
	local PLATFORM_IRIX64_KERNELBITS=( "64" )
	local PLATFORM_IRIX64_64_CPUTYPE=( "mips" )
	local PLATFORM_Darwin_KERNELBITS=( "32" "64" )
	local PLATFORM_Darwin_64_CPUTYPE=( "x86_64" )
	local PLATFORM_Linux_KERNELBITS=( "32" "64" )
	local PLATFORM_Linux_32_CPUTYPE=( "i686" "ppc32" "ppc64" )
	local PLATFORM_Linux_64_CPUTYPE=( "x86_64" "ppc64" )
	local PLATFORM_SunOS_KERNELBITS=( "32" "64" )
	local PLATFORM_SunOS_32_CPUTYPE=( "i686" "sparc" )
	local PLATFORM_SunOS_64_CPUTYPE=( "i686" "sparc" )
	local PLATFORM_OSF1_KERNELBITS=( "64" )
	local PLATFORM_OSF1_64_CPUTYPE=( "alpha" )

	for name in "${PLATFORM_KERNELNAME[@]}"
	do
		# Work-around for "HP-UX"
		local lname
		if [[ "${name}" == "HP-UX" ]]
		then
			lname="HPUX"
		else
			lname="${name}"
		fi
		local bitsarrayname="PLATFORM_${lname}_KERNELBITS"
#		for bits in "${PLATFORM_${lname}_KERNELBITS[@]"
#		do
#
#		done

	done

	
}

platform_config ()
{
	# Configures the CPUTYPE and KERNELBITS variables
	# CPUTYPE is based on uname -p for nearly all KERNELNAME/OSTYPE

	# If passed three arguments, forcibly sets KERNELNAME, KERNELBITS, and CPUTYPE

	# BSD Arguments defaults to 0 (false)
	BSDARGS=0

	# Given a KERNELNAME, can reliably determine how to figure out CPUTYPE and KERNELBITS
	KERNELNAME=`uname -s`
	if [[ "$KERNELNAME" == "AIX" ]]; then
		CPUTYPE=`/usr/bin/uname -p`
		KERNELBITS=`/usr/bin/getconf KERNEL_BITMODE`
		BSDARGS=0
	elif [[ "$KERNELNAME" == "CYGWIN_NT-5.1" ]]; then
		CPUTYPE="$(uname -m)"
		if [[ "${CPUTYPE}" == i*86 ]]; then
			KERNELBITS="32"
		else
			KERNELBITS="64"
		fi
		BSDARGS=0
	elif [[ "$KERNELNAME" == "Darwin" ]]; then
		CPUTYPE=`/usr/bin/uname -p`
		KERNELBITS=64
		BSDARGS=1
	elif [[ "$KERNELNAME" == "HP-UX" ]]; then
		# Possibilities
		# `uname -m` = "9000/800" --> PA-RISC, "ia64" --> Itanium
		# `model` = r?XXYY, where ? = "p" (PA-RISC) or "x" (Itanium)
		# `getconf CPU_VERSION` @see /usr/include/sys/unistd.h for usage
		# `getconf CPU_CHIP_TYPE`
 		CPUTYPE=`uname -m`
		if [[ "$CPUTYPE" != "ia64" ]]; then
		  CPUTYPE="pa"
		fi
		KERNELBITS=`/usr/bin/getconf KERNEL_BITS`
		BSDARGS=1
	elif [[ "$KERNELNAME" == "IRIX64" ]]; then
		CPUTYPE=`/usr/bin/uname -p`
		KERNELBITS=64
		BSDARGS=0
	elif [[ "$KERNELNAME" == "Linux" ]]; then
		CPUTYPE=`/bin/uname -p`
		# On Ubuntu/Debian systems, reports "unknown", try again with -m for machine type
		if [[ "${CPUTYPE}" == "unknown" ]]; then
			CPUTYPE=`/bin/uname -m`
		fi
		if [[ "$CPUTYPE" == "athlon" ]]; then
			CPUTYPE="i686"
		fi
		# On ppc64, always reports 32 even if kernel is 64-bit. Consider using `uname -r` or file on the running kernel
		if [[ "$CPUTYPE" == "ppc64" ]]; then
		  KERNELBITS=64
		else
			KERNELBITS=`/usr/bin/getconf LONG_BIT`
		fi
		BSDARGS=0
	elif [[ "$KERNELNAME" == "SunOS" ]]; then
		CPUTYPE=`/usr/bin/uname -p`
		KERNELBITS=`isainfo -b`
		BSDARGS=0
	elif [[ "$KERNELNAME" == "OSF1" ]]; then
		CPUTYPE=`/usr/bin/uname -p`
		KERNELBITS=64
		BSDARGS=0
	elif [[ "$KERNELNAME" == "Windows_NT" ]]; then
		CPUTYPE=`uname -p`
		if [[ "${CPUTYPE}" == "586" ]]; then
			CPUTYPE="i686"
			KERNELBITS=32
		elif [[ "${CPUTYPE}" == "8664" ]]; then
			CPUTYPE="x86_64"
			KERNELBITS=64
		fi
		BSDARGS=0
	else
		#echo "Unrecognized OS: $KERNELNAME"
		CPUTYPE=`/usr/bin/uname -p`
		KERNELBITS=64
	fi
	export CPUTYPE KERNELNAME KERNELBITS BSDARGS
}

platform_desc ()
{
	echo "KERNELNAME=$KERNELNAME"
	echo "KERNELBITS=$KERNELBITS"
	echo "CPUTYPE=$CPUTYPE"
	echo "BSDARGS=$BSDARGS"
}

platform_platformpath ()
{
	# Defines the 64- and 32-bit PLATFORMPATH variables
	if [[ "$KERNELNAME" == AIX ]]; then
		# if KERNEL_BITS has not been defined, assume the machine is 64-bit
		if [[ -z "$KERNEL_BITS"  || "$KERNEL_BITS" == "64" ]]; then
			PLATFORMPATH="AIX/64/powerpc"
			PLATFORMPATH32="AIX/32/powerpc"
		elif [[ "$KERNEL_BITS" == "32" ]]; then
			PLATFORMPATH="AIX/32/powerpc"
			PLATFORMPATH32="$PLATFORMPATH"
		fi
	elif [[ "$KERNELNAME" == "CYGWIN_NT-5.1" ]]; then
		if [[ "$CPUTYPE" == i*86 ]]; then
			PLATFORMPATH="Windows/32/i686"
			PLATFORMPATH32="${PLATFORMPATH}"
		else
			PLATFORMPATH="Windows/64/x86_64"
			PLATFORMPATH32="Windows/32/i686"
		fi
	elif [[ "$KERNELNAME" == "Darwin" ]]; then
		if [[ "$CPUTYPE" == i*86 || "$CPUTYPE" == "x86_64" ]]; then
			if [[ "$KERNEL_BITS" == 32 ]]; then
				PLATFORMPATH="Darwin/32/i686"
				PLATFORMPATH32="${PLATFORMPATH}"
			elif [[ "$KERNELBITS" == 64 ]]; then
				PLATFORMPATH="Darwin/64/x86_64"
				PLATFORMPATH32="Darwin/32/i686"
			else
				echo "ERROR: Unsupported ${KERNEL_BITS} bit kernel detected"
				return 1
			fi
		fi
	elif [[ "$KERNELNAME" == Linux ]]; then
		if [[ "$CPUTYPE" == ppc64* ]]; then
			PLATFORMPATH="Linux/64/ppc64"
			PLATFORMPATH32="Linux/32/ppc32"
		elif [[ "$CPUTYPE" == i386* || "$CPUTYPE" == 'i686' ]]; then
			PLATFORMPATH="Linux/32/i686"
			PLATFORMPATH32="${PLATFORMPATH}"
		elif [[ "$CPUTYPE" == x86_64* ]]; then
			PLATFORMPATH="Linux/64/x86_64"
			PLATFORMPATH32="Linux/32/i686"
		fi
	elif [[ "$KERNELNAME" == "Windows_NT" ]]; then
		if [[ -z "$KERNEL_BITS"  || "$KERNEL_BITS" == "64" ]]; then
			PLATFORMPATH="Windows/64/x86_64"
			PLATFORMPATH32="Windows/32/i686"
		elif [[ "$KERNEL_BITS" == "32" ]]; then
			PLATFORMPATH="Windows/32/i686"
			PLATFORMPATH32="$PLATFORMPATH"
		fi
	else
		echo "ERROR: Unknown platform"
		return 1
	fi
	export PLATFORMPATH
	export PLATFORMPATH32
}

platform_distributor ()
{
	if [[ "$OSTYPE" == linux* ]]; then
		which lsb_release &>/dev/null
		if [[ "$?" == 1 ]]; then
			echo "lsb_release tool not found in PATH"
			if [ -x "/usr/bin/lsb_release" ]; then
				echo "lsb_release found at /usr/bin/lsb_release. Please add /usr/bin to PATH"
			fi
			return 1
		else
			OSDISTRIBUTOR=$(lsb_release -i | awk -F: '{distributor=$2; gsub(/^[ \t]+|[ \t]+$/,"",$2); print $2}')
			OSRELEASE=$(lsb_release -r | awk -F: '{release=$2; gsub(/^[ \t]+|[ \t]+$/,"",$2); print $2}')
		fi
	else
		OSDISTRIBUTOR="Unknown"
		OSRELEASE="Unknown"
	fi
	export OSDISTRIBUTOR OSRELEASE
	#echo $OSDISTRIBUTOR $OSRELEASE
}

platform_toolspath ()
{
	export TOOLSPATH="${TOOLSPATH_BASE}/${PLATFORMPATH}"
	export TOOLSPATH32="${TOOLSPATH_BASE}/${PLATFORMPATH32}"
	export GENERIC_ARCH="generic"
	export TOOLSPATHGENERIC="${TOOLSPATH_BASE}/${GENERIC_ARCH}"
}

cdtools () { cd "${TOOLSPATH}"; }
cdtools32 () { cd "${TOOLSPATH32}"; }
cdtoolsgeneric () { cd "${TOOLSPATHGENERIC}"; }
