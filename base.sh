#!/bin/bash
#: title	: base
#: date		: 2011-jul-09
#: Authors	: "Daniel Norte de Moraes" <danielcheagle@gmail.com>
#: Authors	: "Marcelo Coraça de Freitas" <marcelo.batera@gmail.com>
#: version	: 1.0
#: Description: base scripts and functions for configuring,compiling and installing.
#: Description: You don't need run this script manually.
#: Description: For It use makefile targets. See INSTALL file.

if [ $# -eq 0 ]; then
	printf "I need minimum of 1 options\n"
	exit 1;
fi;

case ${1,,} in  
	"configure" ) my_commande='configuring' ;;
	"compile" ) my_commande='compilling' ;;
	"install" ) my_commande='installing' ;;
	"clean" ) my_commande='cleaning' ;;
	"distclean" ) my_commande='dist_cleaning' ;;
	* ) printf "I dont known this command take 1 :-\)\n" ;
		exit 1
		;;
esac;

shift 1 ;

global_ifs_bk="$IFS"

##################################
##### support functions ##########
##################################

#####################
### sanitization  ###
#####################

_choose_so(){
#: title	: _choose_so
#: date		: 2011-jul-15
#: Authors	: "Daniel Norte de Moraes" <danielcheagle@gmail.com>
#: Authors	: "Marcelo Coraça de Freitas" <marcelo.batera@gmail.com>
#: version	: 1.0
#: Description: sanitize list of Systems Operations separated by ","
#: Options	:  "OSes"

local _oses=$1
_oses=${_oses:=linux}
_oses=${_oses,,}
local my_oses=
local a=
for a in linux mswindows darwin bsd other
do
	case $_oses in
		*all*) my_oses=linux,mswindows,darwin,bsd,other
			break
			;;
		*"$a"*) my_oses=${my_oses:+${my_oses},}$a
			;;
	esac
done
my_oses=${my_oses:=linux}
printf $my_oses

} # end 

_choose_libtype(){
#: title	: _choose_libtype
#: date		: 2011-jul-15
#: Authors	: "Daniel Norte de Moraes" <danielcheagle@gmail.com>
#: Authors	: "Marcelo Coraça de Freitas" <marcelo.batera@gmail.com>
#: version	: 1.0
#: Description: sanitize list of lib types separated by ","
#: Options	: "libtype,libtype_n"

local _libtypes=$1
_libtypes=${_libtypes:=dynamic,static}
_libtypes=${_libtypes,,}
local my_libtypes=
local a=
for a in static dynamic relocatable
do
	case $_libtypes in
		*all*) my_libtypes=static,dynamic,relocatable
			break
			;;
		*"$a"*) my_libtypes=${my_libtypes:+${my_libtypes},}$a
			;;
	esac
done
my_libtypes=${my_libtypes:=dynamic,static}
printf $my_libtypes

} # end 

_choose_debug(){
#: title	: _choose_debug
#: date		: 2011-jul-15
#: Authors	: "Daniel Norte de Moraes" <danielcheagle@gmail.com>
#: Authors	: "Marcelo Coraça de Freitas" <marcelo.batera@gmail.com>
#: version	: 1.0
#: Description: choose the type of lib, related about debug information
#: Options	:  "with_debug_too"

local _with_debug_too=$1
_with_debug_too=${_with_debug_too:=no}
_with_debug_too=${_with_debug_too,,}
local my_with_debug_too=

case $_with_debug_too in
	*onlydebug* )	my_with_debug_too=debug
		;;
	*yes* )	  my_with_debug_too=normal,debug
		;;
	*no* )	  my_with_debug_too=normal
		;;
esac
my_with_debug_too=${my_with_debug_too:=normal}
printf $my_with_debug_too

} # end

_discover_acmd_path(){
#: title	: _discover_acmd_path
#: date		: 2011-jul-15
#: Authors	: "Daniel Norte de Moraes" <danielcheagle@gmail.com>
#: Authors	: "Marcelo Coraça de Freitas" <marcelo.batera@gmail.com>
#: version	: 1.0
#: Description:  Discover automatically a _PATH_ for a command OR use a default
#: Options	: "cmd" "add_these_path(s)" "or_default_path"
# need more sanitization
#
local cmdo="$1"
local these_paths="$2"
local default_path="$3"
local path_backup="$PATH"
case $cmdo in
	*\)* | *\(* | *\{* | *\}* | *\$*  )  printf '/usr/bin/boo' ; exit 1
		;;
esac
local my_path="$(PATH="$these_paths:$path_backup"; which "$cmdo" || printf "$default_path/stub" )"
printf "$(dirname $my_path )"

} #end

##################################
##### target functions ##########
##################################

_configure(){
#: title	: configure
#: date		: 2011-jul-09
#: Authors	: "Daniel Norte de Moraes" <danielcheagle@gmail.com>
#: Authors	: "Marcelo Coraça de Freitas" <marcelo.batera@gmail.com>
#: version	: 1.01
#: Description: made configuration for posterior compiling by gprbuild.
#: Description: You don't need run this script manually.
#: Options	:  "OSes" "libtypes,libtypes_n" "compiler_path1:compiler_pathn"  \
#:		"system_libs_path1:system_libs_pathn"  "ssl_include_paths" "pg_config_path"  \
#:		"gprconfig_path"  "gprbuild_path"  "with_debug_too"

if [ $# -ne 9 ]; then
	printf ' You dont need use it by hand. read INSTALL for more info and direction.' ; printf "\n" ;
	printf 'configura "OSes" "libtype,libtype_n" "compiler_path1:compiler_path_n" "system_libs_path1:system_libs_paths_n"  "ssl_include_path" "pg_config_path"  "gprconfig_path"  "gprbuild_path"  "with_debug_too" ' ; printf "\n" ;
	
	exit 1
fi;

local ifsbackup="$IFS"
local IFS="$ifsbackup"

local my_version=$(cat version)
local my_atual_dir=$(pwd)
local my_oses=$(_choose_so "$1" )
local my_libtypes=$(_choose_libtype "$2" )

local _base_name=
local my_compiler_paths=$3
local my_system_libs_paths=
local _system_libs_paths=$4
local my_ssl_include_path=
local _ssl_include_path=$5
local my_pg_config_path=
local _pg_config_path=$6
local my_gprconfig_path=
local _gprconfig_path=$7
local my_gprbuild_path=
local _gprbuild_path=$8
local my_with_debug_too=$(_choose_debug "$9" )


# fix me if necessary:
# need more sanitization
_pg_config_path=${_pg_config_path:=$(_discover_acmd_path "pg_config" "$my_compiler_paths" "/usr/bin" )}
#_pg_config_path=${_pg_config_path//[''``]/""}
my_pg_config_path=$_pg_config_path

_gprconfig_path=${_gprconfig_path:=$(_discover_acmd_path "gprconfig" "$my_compiler_paths" "/usr/bin" )}
my_gprconfig_path=$_gprconfig_path

_gprbuild_path=${_gprbuild_path:=$(_discover_acmd_path "gprbuild" "$my_compiler_paths" "/usr/bin" )}
my_gprbuild_path=$_gprbuild_path

_ssl_include_path=${_ssl_include_path:=/usr/lib/openssl}
my_ssl_include_path=${_ssl_include_path}

_system_libs_paths=${_system_libs_paths:=/usr/lib}

local at_count=
local max_count=11
# 10(ten) libs is a resonable value for now.
# if you need more , feel free to contact us and suggest changes. :-)
IFS=";:$ifsbackup"
for alibdirsystem in $_system_libs_paths
do
	[ ${at_count:=1} -ge ${max_count:=11} ] && break;
	madeit=" lib_system$at_count=\"-L$alibdirsystem\"  "
	eval $madeit
	at_count=$(( $at_count + 1 ))
done
IFS=",$ifsbackup"

local made_dirs=${my_atual_dir}/build

for sist_oses in $my_oses
do
	for libbuildtype in $my_libtypes
	do
		for debuga in $my_with_debug_too
		do
			my_tmp="$made_dirs"/$sist_oses/$libbuildtype/$debuga
			mkdir -p "$my_tmp"

			IFS="$ifsbackup"  # the min one blank line below here _is necessary_ , otherwise IFS will affect _only_ next command_ ;-)

			#min two spaces before "\n" because quotes
			{	printf	"$my_ssl_include_path  \n"
				printf	"$my_compiler_paths  \n"
				printf	"$my_gprconfig_path  \n"
				printf	"$my_gprbuild_path  \n"
				printf	"${my_pg_config_path}  \n"
			}>"$my_tmp/kov.log"

			local madeit3=
			local at_count_tmp=
			local madeit2=

				#min two spaces before "\n" because quotes
			{	printf	"version:=\"$my_version\"  \n"
				printf	"myhelpsource:=\"$my_atual_dir/src-c/\"  \n"
				printf	"mysource:=\"$my_atual_dir/src/\"  \n"
				printf	"basedir:=\"$my_atual_dir/build\"  \n"	
				while [ ${at_count_tmp:=1} -lt ${at_count:=11} ]
				do
					madeit2="lib_system$at_count_tmp" ;
					madeit3="${madeit3:+${madeit3},} \$$madeit2 " ;
					printf  "${madeit2}:=\"${!madeit2}\"  \n" ;				
					at_count_tmp=$(( $at_count_tmp + 1 )) ;
				done ;
				printf "\n"

			}>"$my_tmp/kov.def"

			cat "$my_atual_dir/apq_postgresql_version_part1.gpr.in.in" > "$my_tmp/apq_postgresql_version.gpr.in"
			printf  '   system_libs  := ( ) & ( ' >> "$my_tmp/apq_postgresql_version.gpr.in" ;
			printf  " $madeit3 " >> "$my_tmp/apq_postgresql_version.gpr.in" ;
			printf  ' ) ' >> "$my_tmp/apq_postgresql_version.gpr.in" ;
			cat "$my_atual_dir/apq_postgresql_version_part3.gpr.in.in" >> "$my_tmp/apq_postgresql_version.gpr.in"
					

			gnatprep "$my_tmp/apq_postgresql_version.gpr.in"  "$my_tmp/apq_postgresql_version.gpr"  "$my_tmp/kov.def"
			cp "$my_atual_dir/apq-postgresql.gpr"  "$my_tmp/"
			cp "$my_atual_dir/apq_postgresqlhelp.gpr"  "$my_tmp/"

			IFS=",$ifsbackup"

			for support_dirs in obj lib_ali ali obj_c lib_ali_c ali_c
			do
				mkdir -p "$my_tmp"/$support_dirs
			done # support_dirs
		done # debuga
	done # libbuildtype
done # sist_oses
IFS="$ifsbackup"

exit 0;   # end ;-)

} #end _configure

_compile(){
	if [ $# -ne 1 ]; then
		printf 'compile "OSes" '
		printf "\n"
		exit 1
	fi
	local ifsbackup="$IFS"
	local IFS="$ifsbackup"

	local my_atual_dir=$(pwd)
	local my_oses=$(_choose_so "$1" )
	local my_libtypes=$(_choose_libtype "all" )
	local my_with_debug_too=$(_choose_debug "yes" )
	local made_dirs="$my_atual_dir/build"
	local my_count=1
	if [ ! -d "$made_dirs" ]; then
		printf ' "build" dir dont exist or dont is a directory '
		printf "\n"
		exit 1
	fi
	
	local line1_my_tmp=
	local line2_debuga=
	local line3_libtype=
	local line4_os=
	local line5_compile_paths=
	local line6_gprconfig_path=
	local line7_gprbuild_path=
	local line8_pg_config_path=

	IFS=",$ifsbackup"


	local sist_oses=
	local libbuildtype=
	local debuga=
	local my_tmp=
		
	for sist_oses in $my_oses
	do
		for libbuildtype in $my_libtypes
		do
			for debuga in $my_with_debug_too
			do
				my_tmp="$made_dirs"/$sist_oses/$libbuildtype/$debuga
				# IFS="$ifsbackup"
				
				if [ -f "$my_tmp/kov.log" ] && \
					[ $(wc -l < "$my_tmp/kov.log" ) -ge 5 ] && \
					[ -f "$my_tmp/apq_postgresql_version.gpr" ] && \
					[ -f "$my_tmp/apq-postgresql.gpr" ] && \
					[ -f "$my_tmp/apq_postgresqlhelp.gpr" ];
				then
					
						line1_my_tmp="$my_tmp"
						line2_debuga="$debuga"
						line3_libtype="$libbuildtype"
						line4_os="$sist_oses"
				
					{	read line9_ssl_include_path
						read line5_compile_paths
						read line6_gprconfig_path
						read line7_gprbuild_path
						read line8_pg_config_path
					}<"$my_tmp/kov.log"
					#  %[:space:]*
					
				
					if	[ -n "$line2_debuga" ] &&  [ -n "$line3_libtype" ] &&  [ -n "$line4_os" ] && \
						[ -n "$line5_compile_paths" ] &&  [ -n "$line6_gprconfig_path" ] &&  [ -n "$line7_gprbuild_path" ] && \
						[ -n "$line8_pg_config_path" ] && [ -n "$line9_ssl_include_path" ];
					then
						while true;
						do
							[ -d "$line6_gprconfig_path" ] && break
							line6_gprconfig_path=$(dirname $line6_gprconfig_path)
						done

						while true;
						do
							[ -d "$line7_gprbuild_path" ] && break
							line7_gprbuild_path=$(dirname $line7_gprbuild_path)
						done

						while true;
						do
							[ -d "$line8_pg_config_path" ] && break
							line8_pg_config_path=$(dirname $line8_pg_config_path)
						done

						my_count=${my_count:=1}
						local madeit1="line1_$my_count=\"$my_tmp\" ";
						local madeit2="line2_$my_count=\"$debuga\" ";
						local madeit3="line3_$my_count=\"$libbuildtype\" ";
						local madeit4="line4_$my_count=\"$sist_oses\" ";
						local madeit5="line5_$my_count=\"${line5_compile_paths%[:space:]*}\" ";
						local madeit6="line6_$my_count=\"${line6_gprconfig_path%[:space:]*}\" ";
						local madeit7="line7_$my_count=\"${line7_gprbuild_path%[:space:]*}\" ";
						local madeit8="line8_$my_count=\"${line8_pg_config_path%[:space:]*}\" ";
						local madeit9="line9_$my_count=\"${line9_ssl_include_path%[:space:]*}\" ";

						eval "$madeit1"
						eval "$madeit2"
						eval "$madeit3"
						eval "$madeit4"
						eval "$madeit5"
						eval "$madeit6"
						eval "$madeit7"
						eval "$madeit8"
						eval "$madeit9"

						my_count=$(( $my_count + 1 ))
					fi
				fi
			done # debuga
		done # libbuildtype
	done # sist_oses

	if [ $my_count -gt 1 ]; then
		while [ ${my_count2:=1} -lt $my_count ];
		do
			eval " madeit1=\"line1_$my_count2\" "
			eval " madeit2=\"line2_$my_count2\" "
			eval " madeit3=\"line3_$my_count2\" "
			eval " madeit4=\"line4_$my_count2\" "
			eval " madeit5=\"line5_$my_count2\" "
			eval " madeit6=\"line6_$my_count2\" "
			eval " madeit7=\"line7_$my_count2\" "
			eval " madeit8=\"line8_$my_count2\" "
			eval " madeit9=\"line9_$my_count2\" "

			$( PATH="$madeit5:$PATH" ;
				cd "$madeit6" ; 
				./gprconfig --batch --config Ada,,default --config C -o "$madeit1/kov.cgpr" ; \
				pq_include=$(cd "$madeit8" ; ./pg_config --includedir ); \
				cd "$madeit7" ; \
				./gprbuild -d --config="$madeit1/kov.cgpr" \
				-Xstatic_or_dynamic=$madeit3 -Xos=$madeit4 \
				-Xdebug_information=$( if [ "$madeit2" = "normal" ]; then printf "no"; else printf "yes"; fi; ) \
				 -P"$madeit1/apq-postgresql.gpr"  -I $pq_include -I $madeit9 
			)
			
			my_count2=$(( $my_count2 + 1 ))

		done

	else
		printf ' nothing to compile '
		printf "\n"
	fi

	exit 0  # end :-)


} #end _compile


####################################
######   operative part   ##########
####################################

case $my_commande in
	'configuring' )  [ $# -eq 9 ] && _configure "$1" "$2" "$3" "$4" "$5" "$6" "$7" "$8" "$9" || printf "configure need nine\(9\) options\n" ; exit 1
		;;
	'compilling' )  [ $# -eq 1 ] && _compile "$1" || printf "compile need one\(1\) option\n" ; exit 1
		;;
	'installing' ) 
		;; 
	'cleaning' ) 
		;;
	'dist_cleaning' )  ;;
	*  ) printf "I dont known this command :-\)\n" ;
		printf "_${my_commande}_\n"
		exit 1
		;;
esac
