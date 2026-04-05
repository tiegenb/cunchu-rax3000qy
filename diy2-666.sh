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

echo "✅ 配置完成"
