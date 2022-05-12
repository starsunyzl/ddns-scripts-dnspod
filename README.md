适用于 OpenWrt 官方 DDNS 客户端（[ddns-scripts](https://openwrt.org/docs/guide-user/base-system/ddns) ）的腾讯云 DNSPod 动态域名更新插件，使用全新的 [腾讯云 API 3.0](https://cloud.tencent.com/document/api/1427/56193) 接口，支持 IPv6。

## 安装

1. 安装 OpenWrt 官方 DDNS 客户端和其它依赖包：  
`opkg install luci-app-ddns bind-host curl openssl-util`
2. 下载最新的插件包：  
`https://github.com/starsunyzl/ddns-scripts-dnspod/archive/refs/heads/main.zip`
3. 将插件包中的 usr 目录上传到 OpenWrt 根目录 /
4. 设置执行权限：  
`chmod 755 /usr/lib/ddns/update_dnspod.sh`
5. 重启 OpenWrt

有时间再提供 ipk 安装包。

## 使用

OpenWrt 各种魔改版泛滥，仅以原版 OpenWrt 为例。登录 OpenWrt 网页，导航到 Services / Dynamic DNS 页面，点击 Add new services 按钮添加服务，IPv4和IPv6需要分别单独添加服务，DDNS Service provider 选择 dnspod（通常在列表的最下面），Create service 后填写如下 Basic Settings 必填项：

- Lookup Hostname：`完整域名`，用于检查对应的 IP 是否需要更新。例：`www.example.com`、`example.com`
- Domain：要更新的 `主机记录@主域名`，例：`www@example.com`，省略 `主机记录` 则更新 `主域名`，例：`@example.com` 或 `example.com`
- Username：你的腾讯云 API 密钥 `SecretId`
- Password：你的腾讯云 API 密钥 `SecretKey`
- Optional Encoded Parameter：要更新的主机记录 `RecordId`。此插件只更新记录，不新增记录，因此你需要事先在腾讯云控制台人工添加一条记录，否则没有对应的 `RecordId`。添加记录后可以使用腾讯云的 API Explorer 在线发起 [`DescribeRecordList`](https://console.cloud.tencent.com/api/explorer?Product=dnspod&Version=2021-03-23&Action=DescribeRecordList) API 调用获取主机记录的 `RecordId`。有时间再实现自动获取 `RecordId`
- Optional Parameter：要更新的主机记录 `线路`，中文，例：`默认`、`电信`
- Use HTTP Secure：勾选
- Path to CA-Certificate：`/etc/ssl/certs`

其他项根据自身需求填写。

腾讯云 API 3.0 使用了更安全、更严格的签名认证方式，要求 OpenWrt 系统时间和标准时间的误差不能超过 5 分钟，否则会认证失败。

## 作者

starsunyzl
