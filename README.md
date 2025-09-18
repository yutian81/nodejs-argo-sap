# Auto-SAP应用部署说明文档

## 修改——新增 `自动部署SAP-all.yml` 工作流

- 运行时，用户可选 `新加坡` `美国` `ALL`，**选择 `ALL` 代表同时部署两个区域**

- **`新加坡` 区域需要以下特定变量：**
   - SG_ORG: 新加坡区域的 Cloud Foundry Organization (组织) 名称。
   - SG_SPACE: 新加坡区域的 Cloud Foundry Space (空间) 名称。
   - UUID_SG: 用于新加坡区域的 UUID。
   - ARGO_DOMAIN_SG: 用于新加坡区域的 Argo Tunnel 域名。
   - ARGO_AUTH_SG: 用于新加坡区域的 Argo Tunnel 认证信息/Token。

- **`美国` 区域需要以下特定变量：**
   - US_ORG: 美国区域的 Cloud Foundry Organization (组织) 名称。
   - US_SPACE: 美国区域的 Cloud Foundry Space (空间) 名称。
   - UUID_US: 用于美国区域的 UUID。
   - ARGO_DOMAIN_US: 用于美国区域的 Argo Tunnel 域名。
   - ARGO_AUTH_US: 用于美国区域的 Argo Tunnel 认证信息/Token。

## GitHub Secrets 其他通用变量

> 所有变量都需要在仓库的 Settings > Secrets and variables > Actions 中添加，不要修改任何文件

- EMAIL: 用于登录 Cloud Foundry 的邮箱地址。
- PASSWORD: 用于登录 Cloud Foundry 的密码。
- NEZHA_SERVER: 哪吒监控的服务器地址（域名或IP）。
- NEZHA_PORT: 哪吒监控的服务器端口，v1不需要。
- NEZHA_KEY: 连接到哪吒监控的密钥。
- SUB_PATH: 节点订阅路径。
- CFIP: Cloudflare 优选 IP 或域名。
- CFPORT: Cloudflare 优选端口。
- CHAT_ID: 用于接收通知的 Telegram Chat ID。
- BOT_TOKEN: 用于发送通知的 Telegram Bot Token。

-------

> **以下为老王原版说明**

## 概述

本项目是自动部署argo节点到SAP Cloud Foundry平台，自动保活的方案

- 视频教程：https://www.youtube.com/watch?v=uHvtVaeVCvE
- telegram交流反馈群组：https://t.me/eooceu

### 前置要求
* GitHub 账户：需要有一个 GitHub 账户来创建仓库和设置工作流
* SAP Cloud Foundry 账户：需要有 SAP Cloud Foundry 的有效账户,点此注册：https://www.sap.com

## 部署步骤

1. Fork本仓库

2. 在Actions菜单允许 `I understand my workflows, go ahead and enable them` 按钮

3. 在 GitHub 仓库中设置以下 secrets（Settings → Secrets and variables → Actions → New repository secret）：
- `EMAIL`: Cloud Foundry账户邮箱
- `PASSWORD`: Cloud Foundry账户密码
- `SG_ORG`: 新加坡组织名称
- `US_ORG`: 美国组织名称
- `SPACE`: Cloud Foundry空间名称

4. **设置Docker容器环境变量(也是在secrets里设置)**
   - 使用固定隧道token部署，请在cloudflare里设置端口为8001：
   - 设置基础环境变量：
     - UUID(节点uuid),如果开启了哪吒v1,部署完一个之后一定要修改UUID,否则agnet会被覆盖
     - ARGO_DOMAIN(固定隧道域名,未设置将使用临时隧道)
     - ARGO_AUTH(固定隧道json或token,未设置将使用临时隧道)
     - SUB_PATH(订阅token,未设置默认是sub)
   - 可选环境变量
     - NEZHA_SERVER(v1形式: nezha.xxx.com:8008  v0形式：nezha.xxx.com)
     - NEZHA_PORT(V1哪吒没有这个)
     - NEZHA_KEY(v1的NZ_CLIENT_SECRET或v0的agent密钥)
     - CFIP(优选域名或优选ip)
     - CFPORT(优选域名或优选ip对应端口)

5. **开始部署**
* 在GitHub仓库的Actions页面找到"自动部署SAP"工作流
* 点击"Run workflow"按钮
* 根据需要选择或填写以下参数：
   - environment: 选择部署环境（staging/production）
   - region: 选择部署区域（SG/US）
   - app_name: （可选）指定应用名称
* 点击绿色的"Run workflow"按钮开始部署

6. **获取节点信息**
* 点开运行的actions，点击Deploy application，找到routes: 后面的域名
* 订阅： 域名/$SUB_PATH    SUB_PATH变量没设置默认是sub  即订阅为：域名/sub


## 保活 
* actions保活可能存在时间误差，建议根据前两天的情况进行适当调整`自动保活SAP.yml`里的cron时间
* 推荐使用keep.sh在vps或nat小鸡上精准保活，下载keep.sh文件到本地或vps上，在开头添加必要的环境变量和保活url然后执行`bash keep.sh`即可

## 注意事项

1. 确保所有必需的GitHub Secrets已正确配置
2. 多区域部署需先开通权限，确保US区域有内存
4. 建议设置SUB_PATH订阅token,防止节点泄露
