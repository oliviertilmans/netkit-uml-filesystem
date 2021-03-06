#     -*- makefile -*-
#
#     Copyright 2007-2008 Massimo Rimondini - Computer Networks Research Group,
#     Roma Tre University.
#
#     This file is part of Netkit.
#
#     Netkit is free software: you can redistribute it and/or modify it under
#     the terms of the GNU General Public License as published by the Free
#     Software Foundation, either version 3 of the License, or (at your option)
#     any later version.
#
#     Netkit is distributed in the hope that it will be useful, but WITHOUT ANY
#     WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
#     FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
#     details.
#
#     You should have received a copy of the GNU General Public License along
#     with Netkit.  If not, see <http://www.gnu.org/licenses/>.


# *********************************** WARNING ************************************
# *********************************** WARNING ************************************
# *********************************** WARNING ************************************
# *********************************** WARNING ************************************
# *********************************** WARNING ************************************
#
# As the filesystem build procedure frequently needs root access to your host, we
# provide no warranty (once more, NO WARRANTY) that using it will not break your
# system. We put all the necessary care in ensuring that no unnecessary
# components are touched, yet interactions with unexpected host settings may
# still happen and cause damage.
# The procedure is meant to be used by developers or people who know how to make
# a filesystem image but miss the necessary tweaks to make it become a Netkit
# filesystem. Standard users, in general, have no reason to execute it.
# Please *** AVOID *** using this procedure if you are not sure about what you are
# doing or are not ready to debug potential serious problems on your host.
#
# ******************************** END OF WARNING ********************************


# The following variables should contain relative paths
FS_MOUNT_DIR_RELATIVE=mounted_fs
TOOLS_SRC_BUILD_DIR_RELATIVE=tools-build


# The following variables should contain absolute paths
FS_BUILD_DIR=$(CURDIR)/fs-build
FS_MOUNT_DIR=$(CURDIR)/$(FS_MOUNT_DIR_RELATIVE)
TOOLS_SRC_DIR=$(FS_BUILD_DIR)/tools-src
TOOLS_SRC_BUILD_DIR=$(TOOLS_SRC_DIR)/$(TOOLS_SRC_BUILD_DIR_RELATIVE)
TWEAKS_DIR=$(FS_BUILD_DIR)/netkit-tweaks

# Debian distribution to be installed in the filesystem image
DEBIAN_VERSION?=wheezy

# Available space in the filesystem image, in MB
FS_SIZE?=4096

# Additional mkfs flags
MKFS_FLAGS?=

# Target architecture of the FS image. Valid values include:
# alpha amd64 arm armel hppa i386 ia64 mips mipsel powerpc s390 sparc
# However, note that it may not be possible to compile some tools from the
# source code if no suitable cross-architecture compiler is installed.
SUBARCH?=amd64

# URL of the Debian mirror to get packages from
DEBIAN_MIRROR?=http://ftp.fi.debian.org/debian

# Comma separated list of packages to be included in the base system install.
# This comes handy should the Debian distribution being installed have broken
# dependencies.
ADDITIONAL_PACKAGES=debconf-utils,locales

# Files where downloaded Debian packages should be put
BASE_PACKAGES_TARBALL_BASENAME=debian-base-packages-$(DEBIAN_VERSION)-$(SUBARCH)
PACKAGES_TARBALL_BASENAME=debian-packages-$(DEBIAN_VERSION)-$(SUBARCH)
BASE_PACKAGES_TARBALL_TIMESTAMP_BASENAME=$(BASE_PACKAGES_TARBALL_BASENAME)-$(shell date +%Y%m%d)
PACKAGES_TARBALL_TIMESTAMP_BASENAME=$(PACKAGES_TARBALL_BASENAME)-$(shell date +%Y%m%d)








##############################################################################
##############################################################################
##############################################################################
## Settings below these lines should never be touched. If you really need to
## alter them, be really *REALLY* careful, as changing even a single character
## may screw file paths or other critical operations, causing damage to your
## host filesystem!!
##############################################################################
##############################################################################
##############################################################################


# The CDPATH environment variable can cause problems
override CDPATH=

# Uncomment this if you prefer to use sudo
SUDO_PFX=/usr/bin/sudo -E -p %u\''s password:'
SUDO_SFX=
# Uncomment this if you prefer to use su
#SUDO_PFX=/bin/su -c '
#SUDO_SFX='

.EXPORT_ALL_VARIABLES:

LC_ALL=en_US.UTF-8

LOSETUP=/sbin/losetup
DEBOOTSTRAP=/usr/sbin/debootstrap

NK_FS_RELEASE=$(shell awk '/filesystem version/ {print $$NF}' netkit-filesystem-version)
# Filesystem label must be at most 16 characters long
FS_LABEL=nkfs-$(SUBARCH)-$(NK_FS_RELEASE)

# It is very important to make the following simply expanded (':=' instead of
# '='). Also, ***DO NOT EVER*** fiddle with the value of this variable, as most
# subsequent commands use its value as the name of a raw device to write to!!!
override LOOP_DEV:=$(shell $(LOSETUP) -f)

SECTOR_SIZE=512
BLOCK_SIZE=1024
SECTORS_PER_TRACK=63
PARTITION_OFFSET_BLOCKS=32
PARTITION_OFFSET_SECTORS:=$(shell expr $(PARTITION_OFFSET_BLOCKS) \* $(BLOCK_SIZE) / $(SECTOR_SIZE))
PARTITION_OFFSET_BYTES:=$(shell expr $(PARTITION_OFFSET_SECTORS) \* $(SECTOR_SIZE))
FS_SIZE_BYTES:=$(shell expr $(FS_SIZE) \* 1024 \* 1024)
FS_SIZE_TRACKS:=$(shell expr $(FS_SIZE_BYTES) / $(SECTORS_PER_TRACK) / $(SECTOR_SIZE))
ACTUAL_FS_SIZE_BYTES:=$(shell expr $(FS_SIZE_TRACKS) \* $(SECTORS_PER_TRACK) \* $(SECTOR_SIZE) - $(PARTITION_OFFSET_BYTES))
ACTUAL_FS_SIZE_BLOCKS:=$(shell expr $(ACTUAL_FS_SIZE_BYTES) / $(BLOCK_SIZE))




define UMOUNT_FS
-$(SUDO_PFX) umount $(FS_MOUNT_DIR)/proc$(SUDO_SFX) >/dev/null 2>&1; true
-$(SUDO_PFX) umount $(FS_MOUNT_DIR)/proc$(SUDO_SFX) >/dev/null 2>&1; true
-$(SUDO_PFX) umount $(FS_MOUNT_DIR)$(SUDO_SFX) >/dev/null 2>&1; true
endef

define SETUP_LOOPDEV
-$(SUDO_PFX) $(LOSETUP) -d $(LOOP_DEV)$(SUDO_SFX) >/dev/null 2>&1; true
$(SUDO_PFX) $(LOSETUP) $(LOOP_DEV) $(CURDIR)/netkit-fs-$(SUBARCH)-$(NK_FS_RELEASE)$(SUDO_SFX)
endef

define SETUP_LOOPFS
-$(SUDO_PFX) $(LOSETUP) -d $(LOOP_DEV)$(SUDO_SFX) >/dev/null 2>&1; true
$(SUDO_PFX) $(LOSETUP) -o $(PARTITION_OFFSET_BYTES) $(LOOP_DEV) $(CURDIR)/netkit-fs-$(SUBARCH)-$(NK_FS_RELEASE)$(SUDO_SFX)
endef

define MOUNT_FS
$(UMOUNT_FS)
$(SETUP_LOOPFS)
mkdir -p $(FS_MOUNT_DIR)
-$(SUDO_PFX) mount $(LOOP_DEV) $(FS_MOUNT_DIR)$(SUDO_SFX)
endef

define CLEAN_MOUNTDIRS
$(UMOUNT_FS)
-$(SUDO_PFX) rm -fr $(FS_MOUNT_DIR)$(SUDO_SFX)
endef

define CLEAN_LOOPDEVS
-for LOOP in /dev/loop[0-9]*; do $(LOSETUP) $${LOOP} | grep -q "netkit-fs" 2>&1 > /dev/null && $(SUDO_PFX) $(LOSETUP) -d $(SUDO_SFX)$${LOOP}; done 2>&1 > /dev/null; true
endef


define CLEAN_LOOPDEV
-$(SUDO_PFX) $(LOSETUP) -d $(LOOP_DEV)$(SUDO_SFX) >/dev/null 2>&1; true
endef







default: help

.PHONY: help
help:
	@echo
	@echo -e "\e[1mAvailable targets are:\e[0m"
	@echo
	@echo -e "  \e[1mfilesystem\e[0m     Build a Netkit filesystem image from scratch. This"
	@echo "                 procedure requires an Internet connection to retrieve"
	@echo "                 the required filesystem packages."
	@echo
	@echo -e "  \e[1mpackage\e[0m    Create a distributable tarball of the Netkit filesystem."
	@echo
	@echo -e "  \e[1mclean\e[0m      Remove files from previous builds."
	@echo
	@echo -e "  \e[1mclean-all\e[0m  Also remove downloaded files."
	@echo
	@echo -e "\e[1mAvailable variables that influence the build process are:"
	@echo
	@echo -e "  \e[1mDEBIAN_VERSION\e[0m   The name of the Debian distribution to be"
	@echo "                   installed. Refer to http://www.debian.org/releases/"
	@echo "                   for the available versions."
	@echo
	@echo -e "  \e[1mFS_SIZE\e[0m          The size of the filesystem image to be created"
	@echo "                   (in terms of available space inside the image),"
	@echo "                   expressed in MB (default: $(FS_SIZE))."
	@echo
	@echo -e "  \e[1mSUBARCH\e[0m          Packages inside the filesystem will be"
	@echo "                   installed for this architecture. This parameter"
	@echo "                   may be influenced by the architecture used"
	@echo "                   while compiling the UML kernel. Possible values"
	@echo "                   are: alpha amd64 arm armel hppa i386 ia64"
	@echo "                   mips mipsel powerpc s390 sparc (default: $(SUBARCH))."
	@echo "                   Note that some installed tools need to be"
	@echo "                   compiled from source, and compilation may"
	@echo "                   not be supported for all the above"
	@echo "                   architectures."
	@echo
	@echo -e "  \e[1mDEBIAN_MIRROR\e[0m    The Debian mirror that is used to"
	@echo "                   retrieve the packages. Use a nearby mirror"
	@echo "                   (default: $(DEBIAN_MIRROR))."
	@echo "                   A list of available mirrors is available"
	@echo "                   at http://www.debian.org/mirror/list."
	@echo
	@echo -e "  \e[1mADDITIONAL_PACKAGES\e[0m Additional packages that should be"
	@echo "                   installed early in the build process. The"
	@echo "                   default set of packages is usually fine."
	@echo
	@echo -e "  \e[1mMKFS_FLAGS\e[0m       Additional flags to pass to mkfs."
	@echo

.PHONY: filesystem
.SILENT: filesystem
filesystem: netkit-fs

.SILENT: netkit-fs
netkit-fs: .sparsify
	$(CLEAN_MOUNTDIRS)
	$(CLEAN_LOOPDEV)
	ln -fs netkit-fs-$(SUBARCH)-$(NK_FS_RELEASE) netkit-fs
	echo
	echo "Filesystem size:   $(FS_SIZE) MB"
	echo "Filesystem offset: $(PARTITION_OFFSET_BYTES) bytes"

.SILENT: netkit-fs-$(SUBARCH)-$(NK_FS_RELEASE)
netkit-fs-$(SUBARCH)-$(NK_FS_RELEASE):
	echo -e "\n\e[1m\e[32m========= Creating disk image... =========\e[0m"
	dd if=/dev/zero of=netkit-fs-$(SUBARCH)-$(NK_FS_RELEASE) count=0 seek=$(FS_SIZE) bs=1M

.SILENT: .partitions_created
.partitions_created: | netkit-fs-$(SUBARCH)-$(NK_FS_RELEASE)
	echo -e "\n\e[1m\e[32m====== Creating partition table... =======\e[0m"
	$(SETUP_LOOPDEV)
	echo "$(PARTITION_OFFSET_SECTORS),,L,*" | $(SUDO_PFX) sfdisk -q -H 1 -S $(SECTORS_PER_TRACK) -uS -L --no-reread $(LOOP_DEV)$(SUDO_SFX)
	: > .partitions_created

.SILENT: .fs_created
.fs_created: .partitions_created
	echo -e "\n\e[1m\e[32m========== Creating filesystem... ========\e[0m"
	$(SETUP_LOOPFS)
	# Mkfs may overestimate the block count if it is not an integer number;
	# therefore the block count must be explicitly specified.
	$(SUDO_PFX) mkfs.ext2 -q -b $(BLOCK_SIZE) $(if $(FS_LABEL),-L $(FS_LABEL),) $(MKFS_FLAGS) $(LOOP_DEV) $(ACTUAL_FS_SIZE_BLOCKS)$(SUDO_SFX)
	$(SUDO_PFX) tune2fs -c 0 -i 0 $(LOOP_DEV)$(SUDO_SFX)
	: > .fs_created

.SILENT: $(BASE_PACKAGES_TARBALL_BASENAME).tgz
$(BASE_PACKAGES_TARBALL_BASENAME).tgz:
	mkdir -p $(FS_MOUNT_DIR)
	echo -e "\n\e[1m\e[33m======= Downloading base packages... =====\e[0m"
	$(DEBOOTSTRAP) --arch=$(SUBARCH) $(if $(ADDITIONAL_PACKAGES),--include $(ADDITIONAL_PACKAGES),) --make-tarball $(CURDIR)/$(BASE_PACKAGES_TARBALL_TIMESTAMP_BASENAME).tgz $(DEBIAN_VERSION) $(FS_MOUNT_DIR) $(DEBIAN_MIRROR)
	ln -fs $(BASE_PACKAGES_TARBALL_TIMESTAMP_BASENAME).tgz $(BASE_PACKAGES_TARBALL_BASENAME).tgz

.SILENT: .base_system_installed
.base_system_installed: $(BASE_PACKAGES_TARBALL_BASENAME).tgz .fs_created
	echo -e "\n\e[1m\e[32m======= Installing base system... ========\e[0m"
	$(MOUNT_FS)
	$(SUDO_PFX) $(DEBOOTSTRAP) --arch=$(SUBARCH) $(if $(ADDITIONAL_PACKAGES),--include $(ADDITIONAL_PACKAGES),) --unpack-tarball $(CURDIR)/$(BASE_PACKAGES_TARBALL_BASENAME).tgz $(DEBIAN_VERSION) $(FS_MOUNT_DIR) $(DEBIAN_MIRROR)
	: > .base_system_installed

.SILENT: .full_system_installed
.full_system_installed: .base_system_installed .uncompressed_packages
	echo -e "\n\e[1m\e[32m=== Installing additional packages... ====\e[0m"
	$(MOUNT_FS)
	-$(SUDO_PFX) chroot $(FS_MOUNT_DIR) mount -t proc none /proc$(SUDO_SFX)
	# First of all, configure the locale installation
	$(SUDO_PFX) sed -ri 's/^# +en_US/en_US/' $(FS_MOUNT_DIR)/etc/locale.gen$(SUDO_SFX)
	$(SUDO_PFX) chroot $(FS_MOUNT_DIR) locale-gen$(SUDO_SFX)
	$(SUDO_PFX) chroot $(FS_MOUNT_DIR) update-locale LANG=en_US.UTF-8 LC_MEASUREMENT=en_US.UTF-8$(SUDO_SFX)
	$(SUDO_PFX) chroot $(FS_MOUNT_DIR) apt-get update$(SUDO_SFX)
	cat $(FS_BUILD_DIR)/debconf-package-selections | $(SUDO_PFX) chroot $(FS_MOUNT_DIR) debconf-set-selections$(SUDO_SFX)
	# Divert some files in order to prevent services from being started
	for DIVERSION in $(shell find $(TWEAKS_DIR)/diversions -type f ! -wholename "*.svn*" -printf "/%P\n"); do \
		$(SUDO_PFX) chroot $(FS_MOUNT_DIR) dpkg-divert --divert `dirname $${DIVERSION}`/orig-`basename $${DIVERSION}` --rename $${DIVERSION}$(SUDO_SFX); \
		[ -s $(TWEAKS_DIR)/diversions/$${DIVERSION} ] && $(SUDO_PFX) cp $(TWEAKS_DIR)/diversions/$${DIVERSION} $(FS_MOUNT_DIR)/$${DIVERSION}$(SUDO_SFX) || true; \
	done

	for PACKAGE in `cat $(FS_BUILD_DIR)/packages-list`; do \
		echo Installing $${PACKAGE}...; \
		$(SUDO_PFX) chroot $(FS_MOUNT_DIR) apt-get install -o APT::Get::AllowUnauthenticated=1 -fqqy $${PACKAGE}$(SUDO_SFX) || exit 1; \
	done
	for DIVERSION in $(shell find $(TWEAKS_DIR)/diversions -type f ! -wholename "*.svn*" -printf "/%P\n"); do \
		if [ -e $(FS_MOUNT_DIR)/`dirname $${DIVERSION}`/orig-`basename $${DIVERSION}`.dpkg-new ]; then \
			$(SUDO_PFX) mv $(FS_MOUNT_DIR)/`dirname $${DIVERSION}`/orig-`basename $${DIVERSION}`.dpkg-new $(FS_MOUNT_DIR)/`dirname $${DIVERSION}`/orig-`basename $${DIVERSION}`$(SUDO_SFX); \
		fi; \
		$(SUDO_PFX) rm -f $(FS_MOUNT_DIR)/$${DIVERSION}$(SUDO_SFX); \
		$(SUDO_PFX) chroot $(FS_MOUNT_DIR) dpkg-divert --rename --remove $${DIVERSION}$(SUDO_SFX); \
	done
	$(SUDO_PFX) chroot $(FS_MOUNT_DIR) apt-get clean$(SUDO_SFX)
	$(SUDO_PFX) chroot $(FS_MOUNT_DIR) debconf-get-selections$(SUDO_SFX) > $(FS_BUILD_DIR)/debconf-package-selections$(SUDO_SFX)
	: > .full_system_installed


.SILENT: .installed_src_tools
.installed_src_tools: .full_system_installed
	echo -e "\n\e[1m\e[32m===== Installing additional tools... =====\e[0m"
	#mkdir -p $(TOOLS_SRC_BUILD_DIR)
	#+$(MAKE) -C $(TOOLS_SRC_BUILD_DIR) -f ../Makefile.devel install-all
	: > .installed_src_tools

.SILENT: .applied_tweaks
.applied_tweaks: .installed_src_tools
	echo -e "\n\e[1m\e[32m=== Applying Netkit-specific tweaks... ===\e[0m"
	$(MOUNT_FS)
	+$(MAKE) -C $(TWEAKS_DIR) -f Makefile.devel netkit-tweaks
	: > .applied_tweaks

.SILENT: $(PACKAGES_TARBALL_BASENAME).tgz
$(PACKAGES_TARBALL_BASENAME).tgz: | .base_system_installed
	echo -e "\n\e[1m\e[33m=== Downloading additional packages... ===\e[0m"
	$(MOUNT_FS)
	$(SUDO_PFX) chroot $(FS_MOUNT_DIR) apt-get update$(SUDO_SFX)
	for PACKAGE in `cat $(FS_BUILD_DIR)/packages-list`; do echo Downloading $${PACKAGE} and its dependencies...; $(SUDO_PFX) chroot $(FS_MOUNT_DIR) apt-get -fqqy --download-only install $${PACKAGE}$(SUDO_SFX); done
	echo "Compressing packages..."; tar -C $(FS_MOUNT_DIR)/var/cache/apt --exclude=lock -czf $(PACKAGES_TARBALL_TIMESTAMP_BASENAME).tgz .
	ln -fs $(PACKAGES_TARBALL_TIMESTAMP_BASENAME).tgz $(PACKAGES_TARBALL_BASENAME).tgz

.SILENT: .uncompressed_packages
.uncompressed_packages: $(PACKAGES_TARBALL_BASENAME).tgz
	echo "Uncompressing packages..."
	$(MOUNT_FS)
	$(SUDO_PFX) tar -C $(FS_MOUNT_DIR)/var/cache/apt -xzf $(PACKAGES_TARBALL_BASENAME).tgz$(SUDO_SFX)
	: > .uncompressed_packages

.SILENT: .sparsify
.sparsify: .applied_tweaks
	echo -e "\n\e[1m\e[32m==== Sparsifying filesystem image... =====\e[0m"
	$(MOUNT_FS)
	-$(SUDO_PFX) dd if=/dev/zero of=$(FS_MOUNT_DIR)/zeros-mass$(SUDO_SFX) >/dev/null 2>&1; true
	$(SUDO_PFX) rm -f $(FS_MOUNT_DIR)/zeros-mass$(SUDO_SFX)
	$(UMOUNT_FS)
	mv netkit-fs-$(SUBARCH)-$(NK_FS_RELEASE) netkit-fs-$(SUBARCH)-$(NK_FS_RELEASE).old
	cp --sparse=always netkit-fs-$(SUBARCH)-$(NK_FS_RELEASE).old netkit-fs-$(SUBARCH)-$(NK_FS_RELEASE)
	rm -f netkit-fs-$(SUBARCH)-$(NK_FS_RELEASE).old
	: > .sparsify








.PHONY: package
package: ../netkit-filesystem-$(SUBARCH)-$(NK_FS_RELEASE).tar.bz2

../netkit-filesystem-$(SUBARCH)-$(NK_FS_RELEASE).tar.bz2: netkit-fs
	mkdir -p build/netkit/fs
	mv netkit-fs-$(SUBARCH)-$(NK_FS_RELEASE) netkit-fs README netkit-filesystem-version installed-packages-* CHANGES build/netkit/fs/
	tar -C build -cSjf ../netkit-filesystem-$(SUBARCH)-$(NK_FS_RELEASE).tar.bz2 netkit

.PHONY: clean
clean:
	$(CLEAN_MOUNTDIRS)
	$(CLEAN_LOOPDEVS)
	-rm -fr $(BUILD_DIR) $(FS_MOUNT_DIR) .partitions_created .fs_created .base_system_installed .full_system_installed .uncompressed_packages .installed_src_tools .applied_tweaks .sparsify netkit-fs-$(SUBARCH)-$(NK_FS_RELEASE) netkit-fs installed-packages-$(SUBARCH)-$(NK_FS_RELEASE) installed-packages build
	-$(MAKE) -C $(TOOLS_SRC_BUILD_DIR) -f ../Makefile.devel clean

.PHONY: clean-all
clean-all: clean
	-rm -f debian-*packages*
	-rm -fr $(TOOLS_SRC_BUILD_DIR)

