#!/bin/bash
#
# Copyright (c) 2019-2020 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
#

# ==================== 修复 shortcut-fe 编译问题 ====================
echo "正在修复 shortcut-fe 编译警告问题..."
if [ -d "package/network/utils/shortcut-fe" ]; then
    # 移除 -Werror 标志，将警告不作为错误处理
    sed -i 's/-Werror/-Wno-error/g' package/network/utils/shortcut-fe/Makefile
    echo "✅ 已修改 shortcut-fe Makefile，禁用 -Werror"
fi
# ==================== 修复结束 ====================

# Modify default IP
#sed -i 's/192.168.1.1/192.168.50.5/g' package/base-files/files/bin/config_generate
