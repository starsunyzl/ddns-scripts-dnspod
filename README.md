适用于 [OpenWrt ddns-scripts](https://openwrt.org/docs/guide-user/base-system/ddns) 的腾讯云 DNSPod 动态域名更新插件，使用全新的 [腾讯云 API 3.0](https://cloud.tencent.com/document/api/1427/56193) 接口，支持 IPv6。

## 安装

1. 安装依赖包：  
`opkg install luci-app-ddns curl openssl-util`
2. 下载最新的插件包：  
https://github.com/starsunyzl/ddns-scripts-dnspod/archive/refs/heads/main.zip
3. 将插件包中的 usr 目录上传到 OpenWrt 根目录 /
4. 设置执行权限：  
`chmod 755 /usr/lib/ddns/update_dnspod.sh`
5. 重启 OpenWrt

## 使用

登录 OpenWrt 网页，导航到 Services / Dynamic DNS 页面，点击 Add new services 按钮添加服务，DDNS Service provider 选择 dnspod（通常在列表的最下面），Create service 后按如下要求填写 Basic Settings 设置：

- Lookup Hostname：用于查询 IP 的完整域名，如：www.example.com、example.com
- Domain：要更新的 主机记录@主域名，如：www@example.com，省略主机记录则更新主域名，如：@example.com、example.com
- Username：你的腾讯云 API 密钥 SecretId
- Password：你的腾讯云 API 密钥 SecretKey
- Optional Encoded Parameter：要更新的主机记录 RecordId。本插件只更新记录，不新增记录，因此你需要事先人工添加一条记录，否则没有对应的 RecordId。添加记录后可以使用腾讯云的 API Explorer 在线发起 [DescribeRecordList](https://console.cloud.tencent.com/api/explorer?Product=dnspod&Version=2021-03-23&Action=DescribeRecordList) API 调用获取主机记录的 RecordId
- Optional Parameter：要更新的主机记录线路，中文，如：默认
- Use HTTP Secure：勾选
- Path to CA-Certificate：/etc/ssl/certs

其他选项根据自身需求设置

## 作者

starsunyzl
