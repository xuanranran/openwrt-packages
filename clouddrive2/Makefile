#
# Copyright (C) 2017-2024
#
# This is free software, licensed under the GNU General Public License v2.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=clouddrive2
PKG_VERSION:=1.2.1
PKG_RELEASE:=1

PKG_MAINTAINER:=Hannibal

include $(INCLUDE_DIR)/package.mk

ifeq ($(ARCH),x86_64)
  PKG_ARCH_Ctl:=x86_64
  PKG_HASH:=4828d0320a67f7e5f37dc6bef9b4f6676cf96540bbcb3f1741c8eb667e3a2f4f
endif
ifeq ($(ARCH),aarch64)
  PKG_ARCH_Ctl:=aarch64
  PKG_HASH:=0a0544641d04265812d2cce75fb5bdecb76d8a23aec0cddecb1579cf5f5e0560
endif
ifeq ($(ARCH),arm)
  PKG_ARCH_Ctl:=armv7
  PKG_HASH:=be32cd8905ed9616411158755d98ed87f73233b52baec1411dd8c969b6f6bacd
endif

define Package/clouddrive2
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=Cloud Manager
  TITLE:=CloudDrive2
  URL:=https://www.clouddrive2.com/
  DEPENDS:=@(arm||aarch64||x86_64) +fuse-utils +ca-bundle
endef

define Package/clouddrive2/description
  CloudDrive2 is a cloud storage mounting tool for OpenWrt.
endef

define Package/clouddrive2/postinst
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] && exit 0
rmdir /bg/clouddrive2 2>/dev/null || true
rmdir /bg 2>/dev/null || true
exit 0
endef

define Download/clouddrive2
  URL:=https://github.com/cloud-fs/cloud-fs.github.io/releases/download/v$(PKG_VERSION)
  URL_FILE:=clouddrive-2-linux-$(PKG_ARCH_Ctl)-$(PKG_VERSION).tgz
  FILE:=clouddrive-2-linux-$(PKG_ARCH_Ctl)-$(PKG_VERSION).tgz
  HASH:=$(PKG_HASH)
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	tar -xzvf $(DL_DIR)/clouddrive-2-linux-$(PKG_ARCH_Ctl)-$(PKG_VERSION).tgz -C $(PKG_BUILD_DIR)/
	# Move files from subfolder to root if they exist in a subfolder
	if [ -d "$(PKG_BUILD_DIR)/clouddrive-2-linux-$(PKG_ARCH_Ctl)-$(PKG_VERSION)" ]; then \
		mv $(PKG_BUILD_DIR)/clouddrive-2-linux-$(PKG_ARCH_Ctl)-$(PKG_VERSION)/* $(PKG_BUILD_DIR)/; \
		rmdir $(PKG_BUILD_DIR)/clouddrive-2-linux-$(PKG_ARCH_Ctl)-$(PKG_VERSION); \
	fi
	ls -al $(PKG_BUILD_DIR)/
endef

define Build/Compile
endef

define Package/clouddrive2/install
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/clouddrive2.init $(1)/etc/init.d/clouddrive2
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/clouddrive2.config $(1)/etc/config/clouddrive2
	$(INSTALL_DIR) $(1)/lib/upgrade/keep.d
	$(INSTALL_DATA) ./files/clouddrive2.upgrade $(1)/lib/upgrade/keep.d/clouddrive2
	$(INSTALL_DIR) $(1)/usr/libexec/rpcd
	$(INSTALL_BIN) ./files/clouddrive2.rpc $(1)/usr/libexec/rpcd/luci.clouddrive2
	$(INSTALL_DIR) $(1)/usr/share/clouddrive2
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/clouddrive $(1)/usr/share/clouddrive2/
	cp -rf $(PKG_BUILD_DIR)/wwwroot $(1)/usr/share/clouddrive2/
endef

$(eval $(call Download,clouddrive2))
$(eval $(call BuildPackage,clouddrive2))
