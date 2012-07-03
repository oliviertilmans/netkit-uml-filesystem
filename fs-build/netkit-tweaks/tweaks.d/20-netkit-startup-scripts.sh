#!/bin/sh

echo "Installing Netkit startup scripts..."
eval "${SUDO_PFX}chroot ${FS_MOUNT_DIR} update-rc.d netkit-phase1 defaults 00 99${SUDO_SFX}" >/dev/null
eval "${SUDO_PFX}chroot ${FS_MOUNT_DIR} update-rc.d netkit-phase2 defaults 99 10${SUDO_SFX}" >/dev/null
eval "${SUDO_PFX}chroot ${FS_MOUNT_DIR} update-rc.d netkit-mount-modules-dir start 00 S stop 99 0 6${SUDO_SFX}" >/dev/null
eval "${SUDO_PFX}chroot ${FS_MOUNT_DIR} update-rc.d netkit-welcome start 01 S${SUDO_SFX}" >/dev/null
