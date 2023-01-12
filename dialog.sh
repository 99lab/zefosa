#!/bin/bash

#function BUL_askYesNo()
#{
#    dialog --yesno "$1" 0 0
#}
#BUL_askYesNo Hello

#MYVAR=$(dialog --inputbox "THIS OUTPUT GOES TO FD 1" 25 25  --output-fd 1)
#
#echo $
#
#
#MYVAR=$(dialog --checklist "Choose toppings:" 0 0 3 \
#    1 Cheese on \
#    2 "Tomato Sauce" on \
#    3 Anchoives off \
#    --output-fd 1)
#
#echo $MYVAR

#MYVAR=$(dialog --fselect /development/ 0 0  --output-fd 1)
#
#echo $MYVAR

DISK=($(lsblk -pe 252 | sed -n '/disk/p' | awk '{ print $1 }' | xargs -I{} find -L /dev/disk/by-id/ -samefile {}))

echo ${#DISK[@]}


MYVAR=$(dialog --checklist "Choose install disks:" 0 0 ${#DISK[@]} \
  $(for i in ${!DISK[@]}; do echo -e $i ${DISK[$i]} \n; done) \
  --output-fd 1)
#
for i in $MYVAR; do
  echo ${DISK[$i]}
done