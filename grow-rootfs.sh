#!/bin/bash

GROWPART=$(which growpart)
if [[ ${?} -ne 0 ]]
then
  echo "Skipping growfs, growpart command is missing"
else
  MOUNT_LINE=$(cat /etc/mtab | grep ' / ' | grep -v '^rootfs')

  DEVICE=$(echo "$MOUNT_LINE" | cut -d' ' -f1)
  DEVICE=$(readlink -f "$DEVICE")
  FSTYPE=$(echo "$MOUNT_LINE" | cut -d' ' -f3)

  DISK=$(echo "$DEVICE" | sed 's/.$//')
  PARTITION=$(echo "$DEVICE" | sed "s|^$DISK||")

  if [ -n $DEBUG ]; then
    echo DEVICE: $DEVICE
    echo FSTYPE: $FSTYPE
    echo DISK: $DISK
    echo PARTITION: $PARTITION
  fi

  growpart "$DISK" "$PARTITION"

  case "$FSTYPE" in
    ext2|ext3|ext4)
      resize2fs "$DEVICE"
      ;;
    xfs)
      xfs_growfs /
      ;;
  esac
fi