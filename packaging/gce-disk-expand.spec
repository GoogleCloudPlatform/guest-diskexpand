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
Name: gce-disk-expand
Summary: Google Compute Engine root disk expansion module
Epoch: 1
Version: %{_version}
Release: g1%{?dist}
License: Apache Software License
Group: System Environment/Base
URL: https://github.com/GoogleCloudPlatform/guest-diskexpand
Source0: %{name}_%{version}.orig.tar.gz

# Base dependencies for all distributions
Requires: e2fsprogs, dracut, grep, util-linux, parted

# On EL<=9, pull in gdisk/sgdisk; EL10+ drops it
%if 0%{?rhel} && 0%{?rhel} < 10
Requires: gdisk
%endif

Conflicts: dracut-modules-growroot

BuildArch: noarch

%description
This package resizes the root partition on first boot using parted.

%prep
%autosetup

%install
mkdir -p %{buildroot}/usr/lib/dracut/modules.d/50expand_root
cp -R src/usr/lib/dracut/modules.d/50expand_root %{buildroot}/usr/lib/dracut/modules.d/
cp src/expandroot-lib.sh %{buildroot}/usr/lib/dracut/modules.d/50expand_root/
mkdir -p %{buildroot}/usr/lib/systemd/system
cp google-disk-expand.service %{buildroot}/usr/lib/systemd/system/
mkdir -p %{buildroot}/usr/bin
cp src/usr/bin/google_disk_expand %{buildroot}/usr/bin/

%files
%attr(755,root,root) /usr/bin/google_disk_expand
%attr(755,root,root) /usr/lib/dracut/modules.d/50expand_root/*
%attr(644,root,root) /usr/lib/systemd/system/google-disk-expand.service

%post
systemctl enable google-disk-expand.service >/dev/null 2>&1 || :
dracut --force

%postun
# On uninstall, not upgrade.
if [ $1 -eq 0 ]; then
  dracut --force
fi
