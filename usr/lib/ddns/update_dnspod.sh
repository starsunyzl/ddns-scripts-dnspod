#!/bin/sh

# author: starsunyzl
# see https://github.com/starsunyzl/ddns-scripts-dnspod for more details

[ -z "$CURL" ] && [ -z "$CURL_SSL" ] && write_log 14 "DNSPod communication require cURL with SSL support. Please install"
[ -z "$domain" ] && write_log 14 "Service section not configured correctly! Missing 'domain'"
[ -z "$username" ] && write_log 14 "Service section not configured correctly! Missing SecretId as 'username'"
[ -z "$password" ] && write_log 14 "Service section not configured correctly! Missing SecretKey as 'password'"
[ -z "$param_enc" ] && write_log 14 "Service section not configured correctly! Missing RecordId as 'param_enc'"
[ $use_https -eq 0 ] && use_https=1  # force HTTPS

# split __HOST __DOMAIN from $domain
# given data:
# example.com or @example.com for "domain record"
# host.sub@example.com for a "host record"
local __HOST="$(printf %s "$domain" | cut -d@ -f1)"
local __DOMAIN="$(printf %s "$domain" | cut -d@ -f2)"

# __DOMAIN = the base domain i.e. example.com
# __HOST   = host.sub if updating a host record or
# __HOST   = "@" for a domain record
[ -z "$__HOST" -o "$__HOST" = "$__DOMAIN" ] && __HOST="@"

local __SECRET_ID="$username"
local __SECRET_KEY="$password"
local __RECORD_ID="$param_enc"
local __RECORD_LINE="$param_opt"

# __RECORD_LINE must be in Chinese, utf-8 encoding
# "\xe9\xbb\x98\xe8\xae\xa4" means "default" in English.
[ -z "$__RECORD_LINE" ] && __RECORD_LINE="$(printf "\xe9\xbb\x98\xe8\xae\xa4")"

# __REQUEST_HOST and __REQUEST_CONTENT_TYPE must be lowercase
local __REQUEST_HOST="dnspod.tencentcloudapi.com"
local __REQUEST_URL="https://$__REQUEST_HOST"
local __REQUEST_SERVICE="dnspod"
local __REQUEST_CONTENT_TYPE="application/json"  # ; charset=utf-8
local __REQUEST_DATE="$(date -u +%Y-%m-%d)"
local __REQUEST_TIMESTAMP="$(date -u +%s)"

local __REQUEST_ACTION __REQUEST_VERSION __REQUEST_BODY

# ModifyDynamicDNS doesn't support IPv6 yet, so we need ModifyRecord.
# Although ModifyRecord supports both IPv4 and IPv6, updating with ModifyDynamicDNS 
# has a much smaller TTL value and seems to be better suited for DDNS.
if [ $use_ipv6 -eq 0 ]; then
  __REQUEST_ACTION="ModifyDynamicDNS"
  __REQUEST_VERSION="2021-03-23"
  __REQUEST_BODY="{\"Domain\":\"$__DOMAIN\",\"SubDomain\":\"$__HOST\",\"RecordId\":$__RECORD_ID,\"RecordLine\":\"$__RECORD_LINE\",\"Value\":\"$__IP\"}"
else
  __REQUEST_ACTION="ModifyRecord"
  __REQUEST_VERSION="2021-03-23"
  __REQUEST_BODY="{\"Domain\":\"$__DOMAIN\",\"SubDomain\":\"$__HOST\",\"RecordId\":$__RECORD_ID,\"RecordLine\":\"$__RECORD_LINE\",\"RecordType\":\"AAAA\",\"Value\":\"$__IP\"}"
fi

local __PROG_PARAM

sha256() {
  local __MSG="$1"
  echo -en "$__MSG" | openssl sha256 | sed "s/^.* //"
}

hmac_sha256_plainkey() {
  local __KEY="$1"
  local __MSG="$2"
  echo -en "$__MSG" | openssl sha256 -hmac "$__KEY" | sed "s/^.* //"
}

hmac_sha256_hexkey() {
  local __KEY="$1"
  local __MSG="$2"
  echo -en "$__MSG" | openssl sha256 -mac hmac -macopt "hexkey:$__KEY" | sed "s/^.* //"
}

dnspod_transfer() {
  local __URL="$__REQUEST_URL"
  local __ERR=0
  local __CNT=0  # error counter
  local __PROG __RUNPROG

  # Use ip_network as default for bind_network if not separately specified
  [ -z "$bind_network" ] && [ "$ip_source" = "network" ] && [ "$ip_network" ] && bind_network="$ip_network"

  __PROG="$CURL -RsS -o $DATFILE --stderr $ERRFILE"
  __PROG="$__PROG $__PROG_PARAM"
  # check HTTPS support
  [ -z "$CURL_SSL" -a $use_https -eq 1 ] && \
    write_log 13 "cURL: libcurl compiled without https support"
  # force network/interface-device to use for communication
  if [ -n "$bind_network" ]; then
    local __DEVICE
    network_get_device __DEVICE $bind_network || \
      write_log 13 "Can not detect local device using 'network_get_device $bind_network' - Error: '$?'"
    write_log 7 "Force communication via device '$__DEVICE'"
    __PROG="$__PROG --interface $__DEVICE"
  fi
  # force ip version to use
  if [ $force_ipversion -eq 1 ]; then
    [ $use_ipv6 -eq 0 ] && __PROG="$__PROG -4" || __PROG="$__PROG -6"  # force IPv4/IPv6
  fi
  # set certificate parameters
  if [ $use_https -eq 1 ]; then
    if [ "$cacert" = "IGNORE" ]; then  # idea from Ticket #15327 to ignore server cert
      __PROG="$__PROG --insecure"  # but not empty better to use "IGNORE"
    elif [ -f "$cacert" ]; then
      __PROG="$__PROG --cacert $cacert"
    elif [ -d "$cacert" ]; then
      __PROG="$__PROG --capath $cacert"
    elif [ -n "$cacert" ]; then    # it's not a file and not a directory but given
      write_log 14 "No valid certificate(s) found at '$cacert' for HTTPS communication"
    fi
  fi
  # disable proxy if no set (there might be .wgetrc or .curlrc or wrong environment set)
  # or check if libcurl compiled with proxy support
  if [ -z "$proxy" ]; then
    __PROG="$__PROG --noproxy '*'"
  elif [ -z "$CURL_PROXY" ]; then
    # if libcurl has no proxy support and proxy should be used then force ERROR
    write_log 13 "cURL: libcurl compiled without Proxy support"
  fi

  __RUNPROG="$__PROG '$__URL'"  # build final command
  __PROG="cURL"      # reuse for error logging

  while : ; do
    write_log 7 "#> $__RUNPROG"
    eval $__RUNPROG      # DO transfer
    __ERR=$?      # save error code
    [ $__ERR -eq 0 ] && return 0  # no error leave
    [ -n "$LUCI_HELPER" ] && return 1  # no retry if called by LuCI helper script

    write_log 3 "$__PROG Error: '$__ERR'"
    write_log 7 "$(cat $ERRFILE)"    # report error

    [ $VERBOSE -gt 1 ] && {
      # VERBOSE > 1 then NO retry
      write_log 4 "Transfer failed - Verbose Mode: $VERBOSE - NO retry on error"
      return 1
    }

    __CNT=$(( $__CNT + 1 ))  # increment error counter
    # if error count > retry_count leave here
    [ $retry_count -gt 0 -a $__CNT -gt $retry_count ] && \
      write_log 14 "Transfer failed after $retry_count retries"

    write_log 4 "Transfer failed - retry $__CNT/$retry_count in $RETRY_SECONDS seconds"
    sleep $RETRY_SECONDS &
    PID_SLEEP=$!
    wait $PID_SLEEP  # enable trap-handler
    PID_SLEEP=0
  done
  # we should never come here there must be a programming error
  write_log 12 "Error in 'dnspod_transfer()' - program coding error"
}

local __HASHED_REQUEST_PAYLOAD="$(sha256 $__REQUEST_BODY)"

local __CANONICAL_REQUEST="POST\n/\n\ncontent-type:$__REQUEST_CONTENT_TYPE\nhost:$__REQUEST_HOST\n\ncontent-type;host\n$__HASHED_REQUEST_PAYLOAD"

local __HASHED_CANONICAL_REQUEST="$(sha256 $__CANONICAL_REQUEST)"

local __STRING_TO_SIGN="TC3-HMAC-SHA256\n$__REQUEST_TIMESTAMP\n$__REQUEST_DATE/$__REQUEST_SERVICE/tc3_request\n$__HASHED_CANONICAL_REQUEST"

local __SECRET_DATE="$(hmac_sha256_plainkey "TC3$__SECRET_KEY" $__REQUEST_DATE)"
local __SECRET_SERVICE="$(hmac_sha256_hexkey $__SECRET_DATE $__REQUEST_SERVICE)"
local __SECRET_SIGNING="$(hmac_sha256_hexkey $__SECRET_SERVICE "tc3_request")"
local __SIGNATURE="$(hmac_sha256_hexkey $__SECRET_SIGNING $__STRING_TO_SIGN)"

local __AUTHORIZATION="TC3-HMAC-SHA256 Credential=$__SECRET_ID/$__REQUEST_DATE/$__REQUEST_SERVICE/tc3_request, SignedHeaders=content-type;host, Signature=$__SIGNATURE"

__PROG_PARAM="-H 'Authorization: $__AUTHORIZATION' -H 'Content-Type: $__REQUEST_CONTENT_TYPE' -H 'Host: $__REQUEST_HOST' -H 'X-TC-Action: $__REQUEST_ACTION' -H 'X-TC-Version: $__REQUEST_VERSION' -H 'X-TC-Timestamp: $__REQUEST_TIMESTAMP' -d '$__REQUEST_BODY'"

dnspod_transfer || return 1

write_log 7 "DDNS Provider answered:\n$(cat $DATFILE)"

grep -iF "Error" $DATFILE >/dev/null 2>&1
[ $? -eq 0 ] && return 1

grep -iE "\"RecordId\": *$__RECORD_ID" $DATFILE >/dev/null 2>&1
return $?  # "0" if found
