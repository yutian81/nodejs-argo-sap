#!/bin/bash

# -----------------------------------------------------------------------------
# 1. 参数配置
# -----------------------------------------------------------------------------

BTP_GLOBAL_API="https://cli.btp.cloud.sap"
JSON_URL="https://raw.githubusercontent.com/yutian81/nodejs-argo-sap/main/sap-region.json"
REGION_KEY="${REGION_CODE}(free)"

if [ -z "$REGION_CODE" ] || [ -z "$CF_SPACE" ] || [ -z "$CF_ORG" ] || [ -z "$BTP_ID" ] || [ -z "$BTP_GLOBAL_API" ] || [ -z "$EMAIL" ] || [ -z "$PASSWORD" ]; then
    echo "❌ 错误：脚本参数不完整或 Secrets 变量缺失。"
    exit 1
fi

echo "============================================================"
echo "🚀 开始执行 ${REGION_CODE} 区域 Cloud Foundry 环境管理"
echo "Org: $CF_ORG, Space: $CF_SPACE, BTP Subaccount ID: $BTP_ID"
echo "============================================================"

# -----------------------------------------------------------------------------
# 2. 安装依赖项
# -----------------------------------------------------------------------------

install_dependencies() {
    echo "🛠️ 正在安装 BTP CLI, CF CLI 和 jq..."

    # 安装 jq 用于 JSON 解析
    sudo apt-get update
    sudo apt-get install -y jq

    # 安装 CF CLI v8
    echo "deb https://packages.cloudfoundry.org/debian stable main" | sudo tee /etc/apt/sources.list.d/cloudfoundry-cli.list
    wget -q -O - https://packages.cloudfoundry.org/debian/cli.cloudfoundry.org.key | sudo apt-key add -
    sudo apt-get update
    sudo apt-get install -y cf8-cli

    # 安装 BTP CLI
    BTP_CLI_URL="https://pub-0f79fe1331244cf0a5c4be2302ea5092.r2.dev/cli/btp-linux-amd64-2.90.2/btp"
    DOWNLOAD_PATH="/tmp/btp-cli"
    curl -L -o "$DOWNLOAD_PATH" "$BTP_CLI_URL"
    sudo mv "$DOWNLOAD_PATH" /usr/local/bin/btp
    sudo chmod +x /usr/local/bin/btp

    btp --version
    cf --version
    echo "✅ 依赖项安装完成."
}

# -----------------------------------------------------------------------------
# 3. 解析 CF API URL
# -----------------------------------------------------------------------------

parse_cf_api() {
    echo "🌐 正在从 $JSON_URL 下载配置并解析 $REGION_KEY 的 CF API..."
    
    # 使用 curl 和 jq 解析 CF_API
    CF_API=$(curl -sL "$JSON_URL" | jq -r '."'"$REGION_KEY"'".api')
    
    if [ -z "$CF_API" ] || [ "$CF_API" == "null" ]; then
        echo "❌ 错误：无法解析 $REGION_KEY 对应的 CF API。请检查远程 JSON 文件和区域键是否正确。"
        exit 1
    fi
    
    echo "✅ CF API 解析结果: $CF_API"
}

# -----------------------------------------------------------------------------
# 4. CF 环境重建函数
# -----------------------------------------------------------------------------

rebuild_cf_environment() {
    echo "🚨 触发 Cloud Foundry 环境重建流程 (Org: $CF_ORG, Region: $REGION_CODE)..."

    # BTP CLI login and target
    echo "1. 使用 BTP CLI 登录全局账户..."
    btp login --url "$BTP_GLOBAL_API" --user "$EMAIL" --password "$PASSWORD" || { echo "❌ BTP 登录失败"; exit 1; }
    
    echo "2. 目标到子账户 $BTP_ID..."
    btp target --subaccount "$BTP_ID" || { echo "❌ BTP 目标子账户失败"; exit 1; }

    echo "3. ⚠️ 正在删除 Cloud Foundry 环境实例 (Org: $CF_ORG)..."
    CF_INSTANCE_ID=$(
        btp list accounts/environment-instance --subaccount "$BTP_ID" --environment CloudFoundry --output json 2>/dev/null | \
        jq -r '.environmentInstances[] | select(.instance_name == "'"$CF_ORG"'") | .id'
    )

    if [ -n "$CF_INSTANCE_ID" ]; then
        echo "找到 CF 实例 ID: $CF_INSTANCE_ID。正在删除..."
        btp delete accounts/environment-instance "$CF_INSTANCE_ID" --subaccount "$BTP_ID" --confirm || true
        echo "CF 实例删除命令已发送。"
    else
        echo "未找到名称为 $CF_ORG 的 Cloud Foundry 实例，跳过删除。"
    fi
    
    echo "4. 等待 60 秒，等待环境实例删除完成..."
    sleep 60
    
    echo "5. 正在重新创建 Cloud Foundry 环境实例 (Org: $CF_ORG)..."
    btp create accounts/environment-instance --subaccount "$BTP_ID" --environment CloudFoundry --service plan --plan trial --parameters "{\"instance_name\":\"$CF_ORG\"}" || { echo "❌ CF 环境实例创建请求失败"; exit 1; }
    if [ $? -ne 0 ]; then
        echo "❌ CF 环境实例创建请求失败 (权限或参数错误)。请检查 BTP 权限和配额。"
        exit 1
    fi

    echo "6. 等待 120 秒，等待环境实例创建完成并变为 OK 状态..."
    sleep 120
    
    # 重新 CF CLI 登录和目标
    
    echo "7. 重新 CF 登录并目标到新创建的 Org ($CF_ORG)..."
    cf login -a "$CF_API" -u "$EMAIL" -p "$PASSWORD" -o "$CF_ORG" || { echo "❌ CF 登录或目标新 Org 失败"; exit 1; }

    echo "8. 正在为用户 $EMAIL 分配 'Org Manager' 权限..."
    cf set-org-role "$EMAIL" "$CF_ORG" OrgManager || { echo "❌ 分配 Org Manager 失败"; exit 1; }

    echo "9. 正在创建空间 $CF_SPACE..."
    if cf create-space "$CF_SPACE"; then
        echo "✅ ${REGION_CODE} Cloud Foundry 环境实例和空间 $CF_SPACE 成功创建。"
    else
        echo "❌ 错误：即使重建后，空间 $CF_SPACE 仍创建失败。请手动检查BTP状态。"
        exit 1
    fi
}

# -----------------------------------------------------------------------------
# 5. 主逻辑执行
# -----------------------------------------------------------------------------

# 1. 安装依赖
install_dependencies

# 2. 解析 CF API
parse_cf_api

# 3. CF 登录到 API
echo "🔐 使用 CF CLI 登录 CF API ($CF_API)..."
cf login -a "$CF_API" -u "$EMAIL" -p "$PASSWORD" || { echo "❌ CF 基础登录失败"; exit 1; }

# 4. 检查 Org
echo "🔍 正在检查组织 $CF_ORG 是否存在..."
# 尝试目标 Org。如果失败（非零退出码），则执行 else 块。
if cf target -o "$CF_ORG" > /dev/null 2>&1; then
    # Org 存在。接下来检查 Space
    echo "✅ ${REGION_CODE} 组织 $CF_ORG 存在，检查空间 $CF_SPACE 是否存在..."
    
    # 尝试目标到 Space
    if cf target -o "$CF_ORG" -s "$CF_SPACE" > /dev/null 2>&1; then
        echo "✅ ${REGION_CODE} 空间 $CF_SPACE 已经存在。无需操作。"
    else
        echo "❌ ${REGION_CODE} 空间 $CF_SPACE 不存在，尝试创建空间..."
        cf target -o "$CF_ORG"
        cf set-org-role "$EMAIL" "$CF_ORG" OrgManager || { echo "❌ 分配 Org Manager 失败。请检查用户是否已被添加到CF Org。"; exit 1; }
        
        # 尝试创建同名空间并检查结果
        if cf create-space "$CF_SPACE"; then
            echo "✅ ${REGION_CODE} 空间 $CF_SPACE 创建完成。"
        else
            # Space 创建失败，触发重建逻辑
            echo "🚨 ${REGION_CODE} 空间 $CF_SPACE 创建失败。触发 Cloud Foundry 环境重建。"
            rebuild_cf_environment
        fi
    fi

else
    # Org 不存在 (或目标失败)，触发 Cloud Foundry 环境重建流程。
    echo "❌ ${REGION_CODE} 组织 $CF_ORG 不存在或无法访问，直接触发 Cloud Foundry 环境重建流程。"
    rebuild_cf_environment
fi

echo "============================================================"
echo "🎉 ${REGION_CODE} 空间设置功能执行完成。目标组织/空间: $CF_ORG / $CF_SPACE。"
echo "============================================================"
