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

# Contains dracut-specific logic for detecting disk, then calls appropriate
# library functions.

# Notes for developing dracut modules: this module must never exit with anything
# other than a 0 exit code. That means no use of set -e or traps on err, and
# every command must be defensively written so that errors are caught and
# logged, rather than causing end of execution. Note that error handling in the
# main() function always calls return 0

main() {
  local rootdev="" disk="" partnum=""

  # Remove 'block:' prefix and find the root device.
  if ! rootdev=$(readlink -f "${root#block:}") || [ -z "${rootdev}" ]; then
    kmsg "Unable to find root device."
    return
  fi

  if ! out=$(split_partition "$rootdev"); then
    kmsg "Failed to detect disk and partition info: ${out}"
    return
  fi

  disk=${out%:*}
  partnum=${out#*:}

  (
    # If we can't obtain an exclusive lock on FD 9 (which is associated in this
    # subshell with the root device we're modifying), then exit. This is needed
    # to prevent systemd from issuing udev re-enumerations and fsck calls before
    # we're done. See https://systemd.io/BLOCK_DEVICE_LOCKING/

    if ! flock -n 9; then
      kmsg "couldn't obtain lock on ${rootdev}"
      exit
    fi

    if ! parted_needresize "$disk" "$partnum"; then
      kmsg "Disk ${rootdev} doesn't need resizing"
      exit
    fi

    if ! parted --help | grep -q 'resizepart'; then
      kmsg "No 'resizepart' command in this parted"
      exit
    fi

    kmsg "Resizing disk ${rootdev}"

    # First, move the secondary GPT to the end and resize the partition.
    # On EL<=9 this uses sgdisk; on EL10 it falls back to sfdisk.
    if ! out=$(sgdisk_fix_gpt "$disk"); then
      kmsg "Failed to fix GPT: ${out}"
    fi
    # After relocating the backup GPT header, force a kernel rescan. Close the
    # lock FD briefly so the kernel can reread the table, then reacquire it.
    exec 9>&-
    reload_partition_table "$disk"
    exec 9<"$rootdev"
    if ! flock -n 9; then
      kmsg "couldn't re-acquire lock on ${rootdev} after GPT fix"
      exit
    fi
    if ! out=$(parted_resizepart "$disk" "$partnum"); then
      kmsg "Failed to resize partition with parted: ${out}"
      # Try growpart as a fallback if available (works well on EL10)
      if command -v growpart >/dev/null 2>&1; then
        if ! out=$(growpart "$disk" "$partnum" 2>&1); then
          kmsg "Fallback growpart also failed: ${out}"
          exit
        fi
      else
        exit
      fi
    fi

    # Ensure the kernel observes the new partition end
    reload_partition_table "$disk"
  ) 9<$rootdev
}

. /lib/expandroot-lib.sh
udevadm settle -t 3
main
udevadm settle -t 3
