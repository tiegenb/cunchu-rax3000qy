#!/bin/bash
# 文件名: diy2.sh
# 功能: OpenWrt 固件自定义配置脚本
# 作者: 铁哥

set -e  # 任何命令失败立即退出
set -u  # 使用未定义变量时退出
set -o pipefail  # 管道命令中任何一个失败都退出

# ==================== 颜色输出定义 ====================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# 错误处理函数
error_exit() {
    log_error "$1"
    log_error "脚本执行失败，正在退出..."
    exit 1
}

# 检查命令执行结果
check_result() {
    if [ $? -ne 0 ]; then
        error_exit "$1"
    fi
}

# ==================== 开始执行 ====================
echo "============================================================"
log_info "开始执行 DIY 配置脚本"
echo "============================================================"

# ==================== 0. 创建必要目录 ====================
log_step "创建配置文件目录..."
mkdir -p files/etc/config || error_exit "创建 files/etc/config 失败"
mkdir -p files/etc/uci-defaults || error_exit "创建 files/etc/uci-defaults 失败"
log_info "目录创建成功"

# ==================== 1. System 配置（主机名） ====================
log_step "配置系统设置..."

cat > files/etc/config/system << 'EOF'
config system
    option hostname 'WiFirepeater'
    option zonename 'Asia/Shanghai'
    option timezone 'CST-8'

config timeserver 'ntp'
    option enabled '1'
    option enable_server '0'
EOF

# 验证 system 配置文件
if [ -f files/etc/config/system ]; then
    if grep -q "hostname 'WiFirepeater'" files/etc/config/system; then
        log_info "✅ 主机名配置: WiFirepeater"
    else
        error_exit "主机名配置写入失败"
    fi
else
    error_exit "system 配置文件创建失败"
fi

# ==================== 2. 默认 IP 修改 ====================
log_step "修改默认管理 IP..."

CONFIG_GENERATE="package/base-files/files/bin/config_generate"

if [ ! -f "$CONFIG_GENERATE" ]; then
    error_exit "找不到文件: $CONFIG_GENERATE"
fi

# 备份原文件
cp "$CONFIG_GENERATE" "${CONFIG_GENERATE}.bak" || error_exit "备份 config_generate 失败"

# 修改 IP
sed -i 's/192\.168\.[0-9]\+\.[0-9]\+/192.168.66.1/g' "$CONFIG_GENERATE" || {
    cp "${CONFIG_GENERATE}.bak" "$CONFIG_GENERATE"
    error_exit "修改默认 IP 失败"
}

# 验证修改
if grep -q "192.168.66.1" "$CONFIG_GENERATE"; then
    log_info "✅ 管理 IP 已设置为: 192.168.66.1"
    rm -f "${CONFIG_GENERATE}.bak"
else
    cp "${CONFIG_GENERATE}.bak" "$CONFIG_GENERATE"
    error_exit "管理 IP 修改验证失败"
fi

# ==================== 3. 无线配置修改 ====================
log_step "配置无线参数..."

MAC80211_SH="package/kernel/mac80211/files/lib/wifi/mac80211.sh"

if [ ! -f "$MAC80211_SH" ]; then
    error_exit "找不到无线配置文件: $MAC80211_SH"
fi

# 备份原文件
cp "$MAC80211_SH" "${MAC80211_SH}.bak" || error_exit "备份 mac80211.sh 失败"

# 恢复备份的函数（用于错误时恢复）
restore_backup() {
    log_warn "恢复原始配置文件..."
    cp "${MAC80211_SH}.bak" "$MAC80211_SH"
}

# ---------- 3.1 修改 SSID ----------
log_info "配置 SSID..."

# 插入 SSID 变量定义
sed -i '/uci -q batch <<-EOF/i\
        # 自定义 SSID 配置\
        if [ "${mode_band}" = "2g" ]; then\
            ssid="铁哥中继器-2.4G"\
        else\
            ssid="铁哥中继器-5G"\
        fi\
' "$MAC80211_SH" || {
    restore_backup
    error_exit "插入 SSID 变量定义失败"
}

# 替换 SSID 设置
sed -i 's/set wireless\.default_radio${devidx}\.ssid=.*/set wireless.default_radio${devidx}.ssid=${ssid}/g' "$MAC80211_SH" || {
    restore_backup
    error_exit "替换 SSID 设置失败"
}

# ---------- 3.2 配置 2.4G 信道自动 ----------
sed -i '/uci -q batch <<-EOF/i\
        # 2.4G 信道自动选择\
        if [ "${mode_band}" = "2g" ]; then\
            channel="auto"\
        fi\
' "$MAC80211_SH" || {
    restore_backup
    error_exit "配置 2.4G 信道失败"
}

# ---------- 3.3 配置 2.4G 高级特性 ----------
# 注意：EOF 必须顶格写，不能有缩进
sed -i '/^	EOF$/i\
		# ========== 2.4G 专属配置 (802.11ax / Wi-Fi 6) ==========\
		if [ "${mode_band}" = "2g" ]; then\
			# 强制锁定 40MHz 频宽（不自动回退到 20MHz）\
			set wireless.radio${devidx}.noscan=1\
			# 设置 AX 模式（HE40 = 802.11ax + 40MHz）\
			set wireless.radio${devidx}.htmode="HE40"\
			# 启用 256-QAM 调制（802.11ax 基础特性）\
			set wireless.radio${devidx}.ldpc=1\
			# 启用 MU-MIMO（多用户多入多出）\
			set wireless.radio${devidx}.mu_beamformer=1\
			# 禁用传统 11b 速率（提升性能）\
			set wireless.radio${devidx}.legacy_rates=0\
			# 启用波束成形\
			set wireless.radio${devidx}.beamforming=1\
		fi\
		# ========== 5G 保持默认配置 ==========\
EOF\
' "$MAC80211_SH" || {
    restore_backup
    error_exit "配置 2.4G 高级特性失败"
}

log_info "✅ 无线配置修改完成"

# ==================== 4. 验证配置 ====================
log_step "验证配置修改结果..."
echo ""

VERIFY_FAILED=0

# 验证 SSID 配置
if grep -q 'ssid="铁哥中继器-2.4G"' "$MAC80211_SH"; then
    log_info "  ✓ 2.4G SSID: 铁哥中继器-2.4G"
else
    log_error "  ✗ 2.4G SSID 配置失败"
    VERIFY_FAILED=1
fi

if grep -q 'ssid="铁哥中继器-5G"' "$MAC80211_SH"; then
    log_info "  ✓ 5G SSID: 铁哥中继器-5G"
else
    log_error "  ✗ 5G SSID 配置失败"
    VERIFY_FAILED=1
fi

# 验证 2.4G 信道自动
if grep -q 'channel="auto"' "$MAC80211_SH"; then
    log_info "  ✓ 2.4G 信道: 自动选择"
else
    log_warn "  ⚠ 2.4G 信道自动配置未找到"
fi

# 验证 AX 模式
if grep -q 'set wireless.radio${devidx}.htmode="HE40"' "$MAC80211_SH"; then
    log_info "  ✓ 2.4G 模式: 802.11ax (Wi-Fi 6 / HE40)"
else
    log_error "  ✗ 2.4G AX 模式配置失败"
    VERIFY_FAILED=1
fi

# 验证强制 40MHz
if grep -q 'set wireless.radio${devidx}.noscan=1' "$MAC80211_SH"; then
    log_info "  ✓ 强制 40MHz 频宽: 已启用"
else
    log_error "  ✗ 强制 40MHz 配置失败"
    VERIFY_FAILED=1
fi

# 验证 256-QAM
if grep -q 'set wireless.radio${devidx}.ldpc=1' "$MAC80211_SH"; then
    log_info "  ✓ 256-QAM 调制: 已启用"
else
    log_warn "  ⚠ 256-QAM 配置未找到"
fi

# 验证 MU-MIMO
if grep -q 'set wireless.radio${devidx}.mu_beamformer=1' "$MAC80211_SH"; then
    log_info "  ✓ MU-MIMO: 已启用"
else
    log_warn "  ⚠ MU-MIMO 配置未找到"
fi

# 验证波束成形
if grep -q 'set wireless.radio${devidx}.beamforming=1' "$MAC80211_SH"; then
    log_info "  ✓ 波束成形: 已启用"
fi

# 验证传统速率禁用
if grep -q 'set wireless.radio${devidx}.legacy_rates=0' "$MAC80211_SH"; then
    log_info "  ✓ 传统 11b 速率: 已禁用"
fi

echo ""

# 检查是否有严重错误
if [ $VERIFY_FAILED -eq 1 ]; then
    restore_backup
    error_exit "配置验证失败，已恢复原始配置"
fi

# 验证通过，删除备份
rm -f "${MAC80211_SH}.bak"
log_info "所有配置验证通过"

# ==================== 5. 配置摘要 ====================
echo ""
echo "============================================================"
log_info "配置摘要"
echo "============================================================"
echo "  主机名:        WiFirepeater"
echo "  管理 IP:       192.168.66.1"
echo "  时区:          Asia/Shanghai (UTC+8)"
echo ""
echo "  2.4G WiFi:"
echo "    SSID:        铁哥中继器-2.4G"
echo "    信道:        自动选择"
echo "    模式:        802.11ax (Wi-Fi 6)"
echo "    频宽:        40MHz (强制锁定)"
echo "    特性:        256-QAM + MU-MIMO + 波束成形"
echo ""
echo "  5G WiFi:"
echo "    SSID:        铁哥中继器-5G"
echo "    配置:        驱动默认"
echo ""
echo "  NTP 服务:      已启用"
echo "============================================================"
log_info "✅ DIY 脚本执行完成！"
echo "============================================================"

exit 0
