## gce-disk-expand package for CentOS/RHEL and Debian

This package is intended to expand the root partition up to 2TB on a GCE VM
without a GPT partition table and over 2TB on GPT partitioned UEFI enabled
images. It consists of two parts:
1. A partition resize script that runs in the initrd, before the root filesystem
   is mounted.
1. A filesystem resize script that runs during OS startup.

This package has been tested on the following distros and versions.

* RHEL/CentOS 7.6+
* RHEL/CentOS 8+
* Debian 10+
