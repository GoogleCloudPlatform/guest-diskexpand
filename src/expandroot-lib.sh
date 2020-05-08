#!/bin/sh
# Copyright 2018 Google Inc. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

kmsg() {
  echo "gce-disk-expand: $@" > /dev/kmsg
}

sgdisk_get_label() {
    local root="$1"
    [ -z "$root" ] && return 0

    if sgdisk -p "$root" | grep -q "Found invalid GPT and valid MBR"; then
        echo "mbr"
    else
        echo "gpt"
    fi
}

sgdisk_fix_gpt() {
  local disk="$1"
  [ -z "$disk" ] && return

  local label=$(sgdisk_get_label "$disk")
  [ "$label" != "gpt" ] && return

  kmsg "Moving GPT header for $disk with sgdisk."
  sgdisk --move-second-header "$disk"
}

# Returns "disk:partition", supporting multiple block types.
split_partition() {
  local root="$1" disk="" partnum=""
  [ -z "$root" ] && return 0

  if [ -e /sys/block/${root##*/} ]; then
    kmsg "Root is not a partition, skipping partition resize."
    return 1
  fi

  disk=${root%%p[0-9]*}
  [ "$disk" = "$root" ] && disk=${root%%[0-9]}

  partnum=${root#${disk}}
  partnum=${partnum#p}

  echo "${disk}:${partnum}"
}

# Checks if partition needs resizing.
parted_needresize() {
  local disk="$1" partnum="$2" disksize="" partend=""
  if [ -z "$disk" ] || [ -z "$partnum" ]; then
    return 1
  fi

  if ! out=$(parted -sm "$disk" unit b print 2>&1); then
    kmsg "Failed to get disk details: ${out}"
    return 1
  fi

  if ! printf "$out" | sed '$!d' | grep -q "^${partnum}:"; then
    kmsg "Root partition is not final partition on disk. Not resizing."
    return 1
  fi

  disksize=$(printf "$out" | grep "^${disk}" | cut -d: -f2)
  partend=$(printf "$out" | sed '$!d' | cut -d: -f4)
  [ -n "$disksize" -a -n "$partend" ] || return 1

  disksize=${disksize%%B}
  partend=${partend%%B}

  # Check if the distance is > .5GB
  [ $((disksize-partend)) -gt 536870912 ]
  return
}

# Resizes partition using 'resizepart' command.
parted_resizepart() {
  local disk="$1" partnum="$2"
  [ -z "$disk" -o -z "$partnum" ] && return

  kmsg "Resizing $disk partition $partnum with parted."
  if ! out=$(parted -sm "$disk" -- resizepart $partnum -1 2>&1); then
    kmsg "Unable to resize ${disk}${partnum}: ${out}"
    return 1
  fi
}
