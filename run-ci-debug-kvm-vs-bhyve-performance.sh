#!/bin/bash

### LICENSE - (BSD 2-Clause) // ###
#
# Copyright (c) 2018, Daniel Plominski (ASS-Einrichtungssysteme GmbH)
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without modification,
# are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice, this
# list of conditions and the following disclaimer.
#
# * Redistributions in binary form must reproduce the above copyright notice, this
# list of conditions and the following disclaimer in the documentation and/or
# other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR
# ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
# ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
### // LICENSE - (BSD 2-Clause) ###

### ### ### ASS // ### ### ###

#// VARIABLES
VM="0001576e-d4f4-e226-de14-9e62eb170c7e"

#// FUNCTION: spinner (Version 1.0)
spinner() {
   local pid=$1
   local delay=0.01
   local spinstr='|/-\'
   while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
         local temp=${spinstr#?}
         printf " [%c]  " "$spinstr"
         local spinstr=$temp${spinstr%"$temp"}
         sleep $delay
         printf "\b\b\b\b\b\b"
   done
   printf "    \b\b\b\b"
}

#// FUNCTION: run script as root (Version 1.0)
check_root_user() {
if [ "$(id -u)" != "0" ]; then
   echo "[ERROR] This script must be run as root" 1>&2
   exit 1
fi
}

#// FUNCTION: check state (Version 1.0)
check_hard() {
if [ $? -eq 0 ]
then
   echo "[$(printf "\033[1;32m  OK  \033[0m\n")] '"$@"'"
else
   echo "[$(printf "\033[1;31mFAILED\033[0m\n")] '"$@"'"
   sleep 1
   exit 1
fi
}

#// FUNCTION: check state without exit (Version 1.0)
check_soft() {
if [ $? -eq 0 ]
then
   echo "[$(printf "\033[1;32m  OK  \033[0m\n")] '"$@"'"
else
   echo "[$(printf "\033[1;33mWARNING\033[0m\n")] '"$@"'"
   sleep 1
fi
}

#// FUNCTION: check state hidden (Version 1.0)
check_hidden_hard() {
if [ $? -eq 0 ]
then
   return 0
else
   #/return 1
   checkhard "$@"
   return 1
fi
}

#// FUNCTION: check state hidden without exit (Version 1.0)
check_hidden_soft() {
if [ $? -eq 0 ]
then
   return 0
else
   #/return 1
   checksoft "$@"
   return 1
fi
}

#// FUNCTION: set new hosts config (ignore ::1 localhost ip6 lx-zone bind)
set_lx_hosts_config() {
LXZONE=$(uname -a | egrep -c "BrandZ virtual linux")
if [ "$LXZONE" = "1" ]
then
cat << "HOSTS" > lx_hosts

127.0.0.1   localhost
::1         ip6-localhost ip6-loopback
ff02::1     ip6-allnodes
ff02::2     ip6-allrouters

# EOF
HOSTS
   sudo cp -fv lx_hosts /etc/hosts
fi
}

#// FUNCTION: clean up old zlogins
cleanup_zlogin() {
   pgrep zlogin | xargs -L 1 -I % kill -9 %
   sleep 1
}

#// FUNCTION: clean up as kvm
cleanup_kvm() {
   vmadm stop "$VM"
   check_hard stopping VM "$VM"
   sleep 2
   vmadm kill "$VM"
   check_soft killing VM "$VM"
   sleep 2
   zfs rollback extra/"$VM"-disk0@_KVM
   zfs rollback extra/"$VM"-disk1@_KVM
   cp -f /etc/zones/"$VM".xml.KVM /etc/zones/"$VM".xml
   vmadm stop "$VM"
   vmadm update "$VM" alias=EXTRA-assg9-all-kvm-sap-ass17uc_KVM
   vmadm list | grep "$VM"
}

#// FUNCTION: clean up as bhyve
cleanup_bhyve() {
   vmadm stop "$VM"
   check_hard stopping VM "$VM"
   sleep 2
   vmadm kill "$VM"
   check_soft killing VM "$VM"
   sleep 2
   zfs rollback extra/"$VM"-disk0_bhyve@_BHYVE
   zfs rollback extra/"$VM"-disk1_bhyve@_BHYVE
   cp -f /etc/zones/"$VM".xml.BHYVE /etc/zones/"$VM".xml
   vmadm stop "$VM"
   vmadm update "$VM" alias=EXTRA-assg9-all-kvm-sap-ass17uc_BHYVE
   vmadm list | grep "$VM"
}

#// FUNCTION: start new vm environment
start_vm() {
   vmadm start "$VM"
   sleep 2
   vmadm list | grep "$VM"
   echo "" # dummy
   #// if KVM
   GET_KVM_INFO=$(vmadm list | grep "$VM" | grep -c "KVM")
   if [ "$GET_KVM_INFO" = "1" ]
   then
      GET_KVM_INFO_PORT=$(vmadm info $VM vnc | grep "port" | tr ' ' '\n' | tail -n1 | sed 's/,//g')
      if [ -z "$GET_KVM_INFO_PORT" ]
      then
         : # dummy
      else
         echo "if that's a KVM vm, use now: KVM PORT $GET_KVM_INFO_PORT"
      fi
   fi
   #// if BHYVE
   GET_BHYVE_INFO=$(vmadm list | grep "$VM" | grep -c "BHYV")
   if [ "$GET_BHYVE_INFO" = "1" ]
   then
      echo "if that's a BHYVE vm, use now: zlogin -C $VM"
   fi
   echo "" # dummy
}

### RUN ###
echo "RUN"

check_root_user

case "$1" in
'kvm')
### ### ### ### ### ### ### ### ###

cleanup_zlogin
check_hard clean up old zlogins

cleanup_kvm
check_hard clean up KVM environment

start_vm
check_hard starting VM "$VM"

### ### ### ### ### ### ### ### ###
echo "" # dummy
printf "\033[1;32mdebug-kvm-vs-bhyve-performance finished.\033[0m\n"
   ;;
'bhyve')
### ### ### ### ### ### ### ### ###

cleanup_zlogin
check_hard clean up old zlogins

cleanup_bhyve
check_hard clean up BHYVE environment

start_vm
check_hard starting VM "$VM"

### ### ### ### ### ### ### ### ###
echo "" # dummy
printf "\033[1;32mdebug-kvm-vs-bhyve-performance finished.\033[0m\n"
   ;;
*)
printf "\033[1;31mWARNING: debug-kvm-vs-bhyve-performance is experimental and its not ready for production. Do it at your own risk.\033[0m\n"
echo "" # usage
echo "usage: $0 { kvm | bhyve }"
;;
esac

### ### ### // ASS ### ### ###
exit 0
# EOF
