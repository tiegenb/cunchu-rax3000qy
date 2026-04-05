#!/bin/bash
# diy-part1.sh - 编译前配置修改

# CPU频率调节支持（修正版）
echo "2. Adding CPU frequency scaling support..."

# 内核CPU调频子系统
./scripts/config --enable CPU_FREQ
./scripts/config --enable CPU_FREQ_GOV_CONSERVATIVE
./scripts/config --enable CPU_FREQ_GOV_ONDEMAND
./scripts/config --enable CPU_FREQ_GOV_PERFORMANCE
./scripts/config --enable CPU_FREQ_GOV_POWERSAVE
./scripts/config --enable CPU_FREQ_GOV_USERSPACE

# CPU调频驱动
./scripts/config --enable CPUFREQ_DT
./scripts/config --enable PM_OPP

# 内核模块包
./scripts/config --enable PACKAGE_kmod-cpufreq-dt

# 用户空间工具
./scripts/config --enable PACKAGE_cpufreq
./scripts/config --enable PACKAGE_luci-app-cpufreq

# 可选：CPU亲和性工具
./scripts/config --enable PACKAGE_coreutils
./scripts/config --enable PACKAGE_coreutils-taskset

echo "   ✓ Enabled CPU frequency scaling support"
echo "   - kmod-cpufreq-dt"
echo "   - cpufreq"
echo "   - luci-app-cpufreq"

# 4. 可选：添加第三方包源（如需取消注释）
# echo "3. Adding third-party feeds..."
# sed -i '$a src-git mypackages https://github.com/xxx/xxx' feeds.conf.default

echo "=========================================="
echo "diy-part1.sh completed successfully!"
echo "=========================================="
