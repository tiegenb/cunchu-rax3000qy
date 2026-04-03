#!/bin/bash
# diy-part1.sh

# 1. 禁用不需要的包
echo "Disabling unnecessary packages..."
for pkg in watchcat wol vlmcsd frpc NATMap xlnetacc; do
    ./scripts/config --disable PACKAGE_${pkg}
    echo "  - Disabled PACKAGE_${pkg}"
done

# 2. 确保 iptables 启用
./scripts/config --enable PACKAGE_iptables
echo "  - Enabled PACKAGE_iptables"

# 3. 可选：添加第三方包源
# sed -i '$a src-git mypackages https://github.com/xxx/xxx' feeds.conf.default

echo "diy-part1.sh completed"
