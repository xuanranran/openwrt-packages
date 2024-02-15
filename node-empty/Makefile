include $(TOPDIR)/rules.mk

PKG_NAME:=node
PKG_VERSION:=v0
PKG_RELEASE:=1

PKG_BUILD_DIR:=$(BUILD_DIR)/node-empty

include $(INCLUDE_DIR)/host-build.mk
include $(INCLUDE_DIR)/package.mk

define Package/node
  SECTION:=lang
  CATEGORY:=Languages
  SUBMENU:=Node.js
  TITLE:=node-empty
endef

define Package/node-npm
  SECTION:=lang
  CATEGORY:=Languages
  SUBMENU:=Node.js
  TITLE:=node-npm-empty
  DEPENDS:=+node
endef

define Package/daed-next/description
  only for openwrt-sdk skips building nodejs from source.
endef

define Build/Compile
endef

$(eval $(call HostBuild))
$(eval $(call BuildPackage,node))
$(eval $(call BuildPackage,node-npm))

