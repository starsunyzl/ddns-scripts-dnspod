适用于 OpenWrt 官方 DDNS 客户端（[ddns-scripts](https://openwrt.org/docs/guide-user/base-system/ddns) ）的腾讯云 DNSPod 动态域名更新插件，使用全新的 [腾讯云 API 3.0](https://cloud.tencent.com/document/api/1427/56193) 接口，支持 IPv6，支持多 IP 记录值。

## 安装

1. 安装 OpenWrt 官方 DDNS 客户端和其它依赖包：  
`opkg install luci-app-ddns bind-host curl openssl-util`
2. 下载最新的插件包：  
`https://github.com/starsunyzl/ddns-scripts-dnspod/archive/refs/heads/main.zip`
3. 将插件包中的 `usr` 目录上传到 OpenWrt 根目录 /
4. 设置执行权限：  
`chmod 755 /usr/lib/ddns/update_dnspod.sh`
5. 重启 OpenWrt

后续再提供 ipk 安装包。

## 使用

OpenWrt 魔改版众多，以原版为例。登录 OpenWrt 网页，导航到 Services / Dynamic DNS 页面，点击 Add new services 添加服务，IPv4和IPv6需要分别单独添加服务，DDNS Service provider 选择 dnspod（通常在列表最末尾），Create service 后填写如下 Basic Settings 项：

- Lookup Hostname：`完整域名`，用于检测对应的 IP 是否需要更新。例：`www.example.com`、`example.com`
- Domain：要更新的 `主机记录@主域名`，例：`www@example.com`，省略 `主机记录` 则更新 `主域名`，例：`@example.com` 或 `example.com`
- Username：你的腾讯云 API 密钥 `SecretId`
- Password：你的腾讯云 API 密钥 `SecretKey`
- Optional Encoded Parameter：选填，要更新的记录 `RecordId`，不填则自动获取。当一个主机记录有多个记录类型相同的 IP 记录值时，必须填写此项指定要更新哪一条记录。可在 Log File Viewer 中查看所有记录的 `RecordId`（需要设置系统日志输出级别为 Debug 并运行一遍插件）

其他项如代理、更新间隔时间等根据自身需求填写，使用 IPv6 时需要在 Advanced Settings / Network 选择对应的网络接口。

腾讯云 API 3.0 使用了更安全、更严格的签名认证方式，要求 OpenWrt 系统时间和标准时间的误差不能超过 5 分钟，否则会认证失败。

当一个主机记录有多个记录类型相同的 IP 记录值时，官方 DDNS 客户端只取第一条 IP 记录值进行显示和检测，可能和你设置的 `RecordId` 对应的 IP 记录值不同，不必理会，插件会正确检测 `RecordId` 对应的 IP 记录值，当已经是最新时不会再更新。

在原版 OpenWrt 21.02.x 上测试正常，其他版本未测试。

## 作者

starsunyzl
