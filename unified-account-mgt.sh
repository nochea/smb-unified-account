#!/usr/bin/env bash
#
# Copyright 2013 Arnaud Mombrial
#
# This file is part of SMB-Unified-Account.sh
#
# SMB-Unified-Account.sh is free software: you can redistribute it 
# and/or modify it under the terms of the GNU General Public License 
# as published by the Free Software Foundation, either version 3 of 
# the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# This program is still beta software.

info="\033[0;40m\033[1;37m"
endinfo="\033[0;37m"
warn="\033[0;40m\033[1;31m"
endwarn="\033[0;37m"

usage() {
    echo -e "
    Usage: $info`basename $0` [-a] OR [-d] OR [-m] OR [-t] <First Name> <Last Name>$endinfo
      -a : add a user
      -d : del a user
      -m : mod a user <group membership>. 
      This option followed by the keyword <reset> removes all membership but $default_group 
      -t : test if a user account already exist\n" >&2
    exit 1
}

# Include specific variable
PWD=$(pwd)
source "$PWD/inc.sh"


aflag=
dflag=
mflag=
tflag=

while getopts 'adhm:t' OPTION
do
  case $OPTION in
      a)  aflag=1
          ;;
      d)  dflag=1
          ;;
      h)  usage
          exit 1
          ;;
      m)  mflag=1
          mval="$OPTARG"
          ;;
      t)  tflag=1
          ;;
      \?) usage
          ;;
  esac
done
shift $(($OPTIND - 1))


#########################################
# GLOBAL :: TESTS
#########################################

# Firstname and Lastname are present ?
if [ -z "$1" -o -z "$2" ]
then
    echo -e "
    Firstname$info and$endinfo Lastname must be specified :$warn Aborting$endwarn"
    usage
    exit 1
else
    firstname=$(echo $1 | tr '[:upper:]' '[:lower:]')
    lastname=$(echo $2 | tr '[:upper:]' '[:lower:]')
fi

# Required argument selectors have been passed ?
if [ -z "$aflag" ] && [ -z "$dflag" ] && [ -z "$mflag" ] && [ -z "$tflag" ]
then
    usage
fi


#########################################
# USER ACCOUNT :: CREATION
#########################################

if [ "$aflag" ]
then
    # echo "aflag Found"
    # We want to create a new user on this system. 
    # First check the user doesn't already exist
    grep $firstname.$lastname /etc/passwd > .tmp
    exist=$(file .tmp | sed -e "s/.tmp: //")
    if [ "$exist" == "ASCII text" ]
    then
        echo -e "
    $info Unix account already exist for $1 $2.$endinfo :$warn Aborting$endwarn \n"
        exit 1
    # User doesn't already exists, so we can create it
    else
        useradd -c "$1 $2" -M -g $default_group $firstname.$lastname
        smbpasswd -a $firstname.$lastname
        echo -e "
    Successfully created unix and samba account fo user$info $firstname.$lastname$endinfo
    $1 $2 is member of the following group : $info $default_group $endinfo\n"
        exit 0
    fi
fi

#########################################
# USER ACCOUNT :: DELETION
#########################################

if [ "$dflag" ]
then
    # echo "dflag Found"
    # for deletion we have to remove samba account prior to unix account, 
    # otherwise smbpasswd  will complain about database corruption
    echo -e "
    Going to remove $info $firstname.$lastname $endinfo samba and unix account.
    Are you sure ? [o/n] " 
    read answer
    if [ $answer = "o" ]
    then
        smbpasswd -x $firstname.$lastname 
        userdel $firstname.$lastname 
        echo -e "
    Successfully removed user $info $firstname.$lastname $endinfo"
        # file ownership
        # we should now have some orphean file, as we just delete unix account.
        # So we change ownership to $default_user
        find $default_path -nouser -exec chown $default_user {} \;
        echo -e "
    Successfully change orphean file ownership to $default_user\n"
        exit 0
    else
        echo "    Aborting"
        exit 1
    fi
fi

#########################################
# USER ACCOUNT :: CHANGE GROUP MEMBERSHIP
#########################################


if [ "$mflag" ]
then
    # echo "mflag Found"
    if [ "$mval" == "reset" ]
    then
        usermod -G $default_group $firstname.$lastname
        echo -e "
    Group membership are now set to :$info $default_group $endinfo \n"
    else
        usermod -G $default_group,$mval $firstname.$lastname
        group_membership=$(groups $firstname.$lastname | sed -e "s/$firstname.$lastname ://")
        echo -e "
    $firstname.$lastname is now member of :$info $group_membership $endinfo \n"
    fi
fi


#########################################
# USER ACCOUNT :: TEST
#########################################

if [ "$tflag" ]
then
    # echo "pflag Found"
    grep $firstname.$lastname /etc/passwd > .tmp
    exist=$(file .tmp | sed -e "s/.tmp: //")
    if [ "$exist" == "ASCII text" ]
    then
        echo -e "
    $info Unix account already exist for $1 $2. $endinfo \n"
        exit 0
    else
        echo -e "
    $info Unix account for $1 $2 doesn't exist. $endinfo \n"
        exit 0
    fi
fi

