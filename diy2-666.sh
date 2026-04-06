#!/bin/bash
# ==================== diy-part2.sh ====================

# 创建必要目录
mkdir -p files/etc/config

# 1. System 配置（直接覆盖）
cat > files/etc/config/system << 'EOF'
config system
    option hostname 'WiFirepeater'
    option description '室外大功率WIFI无线中继器'
    option zonename 'Asia/Shanghai'
    option timezone 'CST-8'
    option log_proto 'udp'
    option conloglevel '8'
    option cronloglevel '5'
    option zram_comp_algo 'lzo'

config timeserver 'ntp'
    option enabled '0'
    option enable_server '0'
EOF

# 2. 默认 IP 修改
if [ -f package/base-files/files/bin/config_generate ]; then
    sed -i 's/192.168.1.1/192.168.66.1/g' package/base-files/files/bin/config_generate
    echo "✅ IP 修改完成"
else
    echo "⚠️ 警告: config_generate 文件不存在"
fi

# 3. 修复 nss-dp 下载问题
PKG_SOURCE_VERSION="480f036cc96d4e5faa426cfcf90fa7e64dff87e8"
PKG_VERSION="NHSS.QSDK.11.5.0.5"

if [ ! -d "dl/qca-nss-dp-${PKG_SOURCE_VERSION}" ]; then
    echo "正在手动克隆 nss-dp 仓库..."
    git clone https://git.codelinaro.org/clo/qsdk/oss/lklm/nss-dp.git dl/qca-nss-dp-${PKG_SOURCE_VERSION}
    cd dl/qca-nss-dp-${PKG_SOURCE_VERSION}
    git checkout ${PKG_SOURCE_VERSION}
    cd ../..
    tar -czf dl/qca-nss-dp-${PKG_VERSION}.tar.gz -C dl qca-nss-dp-${PKG_SOURCE_VERSION}
    echo "✅ nss-dp 源码已手动处理完成"
else
    echo "nss-dp 源码已存在，跳过"
fi

echo "✅ 配置完成"
