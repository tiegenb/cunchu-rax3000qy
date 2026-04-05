#!/bin/bash
# ==================== diy-part2.sh ====================
# 这个脚本在编译过程中执行，用于自定义配置

echo "开始执行 DIY 配置..."

# ==================== 编译时直接覆盖配置文件 ====================
# 创建 files 目录结构
mkdir -p files/etc/config

# 1. 写入 system 配置文件
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

# 检查 system 配置文件是否写入成功
if [ ! -f "files/etc/config/system" ]; then
    echo "❌ ERROR: system 配置文件写入失败"
    exit 1
fi
echo "✅ system 配置文件写入成功"

# 2. 写入 wireless 配置文件
cat > files/etc/config/wireless << 'EOF'
config wifi-device 'radio0'
    option type 'mac80211'
    option htmode 'HE40'
    option channel 'auto'
    option cell_density '0'
    option mu_beamformer '1'
    option txpower '18'
    option country 'US'

config wifi-iface 'default_radio0'
    option device 'radio0'
    option network 'lan'
    option mode 'ap'
    option ssid '铁哥中继器-2.4G'
    option encryption 'none'

config wifi-device 'radio1'
    option type 'mac80211'
    option htmode 'HE80'
    option channel 'auto'
    option cell_density '0'
    option mu_beamformer '1'
    option txpower '30'
    option country 'US'

config wifi-iface 'default_radio1'
    option device 'radio1'
    option network 'lan'
    option mode 'ap'
    option ssid '铁哥中继器-5G'
    option encryption 'none'
EOF

# 检查 wireless 配置文件是否写入成功
if [ ! -f "files/etc/config/wireless" ]; then
    echo "❌ ERROR: wireless 配置文件写入失败"
    exit 1
fi
echo "✅ wireless 配置文件写入成功"

# 验证 wireless 配置文件内容
if ! grep -q "铁哥中继器-2.4G" files/etc/config/wireless; then
    echo "❌ ERROR: wireless 配置中缺少 2.4G SSID"
    exit 1
fi

if ! grep -q "铁哥中继器-5G" files/etc/config/wireless; then
    echo "❌ ERROR: wireless 配置中缺少 5G SSID"
    exit 1
fi
echo "✅ wireless 配置文件内容验证通过"

# 3. 修改默认 IP
echo "正在修改默认 IP 为 192.168.66.1..."

# 备份原文件
cp package/base-files/files/bin/config_generate package/base-files/files/bin/config_generate.bak

# 执行替换
sed -i 's/192.168.1.1/192.168.66.1/g' package/base-files/files/bin/config_generate

# 检查替换是否成功
if grep -q "192.168.1.1" package/base-files/files/bin/config_generate; then
    echo "❌ ERROR: IP 替换失败，文件中仍存在 192.168.1.1"
    mv package/base-files/files/bin/config_generate.bak package/base-files/files/bin/config_generate
    exit 1
fi

if ! grep -q "192.168.66.1" package/base-files/files/bin/config_generate; then
    echo "❌ ERROR: IP 替换失败，文件中未找到 192.168.66.1"
    mv package/base-files/files/bin/config_generate.bak package/base-files/files/bin/config_generate
    exit 1
fi

rm -f package/base-files/files/bin/config_generate.bak
echo "✅ IP 修改成功 (192.168.1.1 → 192.168.66.1)"

echo "=========================================="
echo "✅ 所有配置已成功写入并验证通过"
echo "=========================================="
