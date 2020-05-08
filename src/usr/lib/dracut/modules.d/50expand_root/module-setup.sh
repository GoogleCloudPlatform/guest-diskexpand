#!/bin/bash

# Copyright 2020 Google Inc. All Rights Reserved.
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

check() {
  command -v parted >/dev/null 2>&1
}

install() {
  inst "$moddir/expandroot-lib.sh" "/lib/expandroot-lib.sh"
  inst_hook cmdline 50 "$moddir/expand_root_dummy.sh"
  inst_hook pre-mount 50 "$moddir/expand_root.sh"

  dracut_install parted
  dracut_install sgdisk
  dracut_install cut
  dracut_install sed
  dracut_install grep
  dracut_install udevadm
}
