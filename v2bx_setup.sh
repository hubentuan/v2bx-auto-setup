#!/usr/bin/env bash
set -euo pipefail

# ============================================
#   V2bX 后端一键配置脚本（中文完整版）
#   作者：hubentuan
#   功能：普通节点 / 家宽S5节点 一键生成所有配置
#   写入目录：/etc/V2bX/
# ============================================

CONFIG_DIR="/etc/V2bX"

# -----------------------------
# 检查 root 权限
# -----------------------------
need_root() {
  if [[ "$(id -u)" -ne 0 ]]; then
    echo "❌ 本脚本需要 root 权限，请使用 sudo 运行！"
    exit 1
  fi
}

# -----------------------------
# 检查 jq 是否安装
# -----------------------------
need_jq() {
  if ! command -v jq >/dev/null 2>&1; then
    echo "❌ 未检测到 jq，请先安装："
    echo "   apt install jq   或   yum install jq"
    exit 1
  fi
}

# -----------------------------
# 输入：ApiHost / ApiKey / NodeID
# -----------------------------
ask_basic_info() {
  echo "======================================"
  echo "         填写节点面板信息"
  echo "======================================"
  read -rp "请输入 ApiHost（例：https://xxx.com）: " API_HOST
  read -rp "请输入 ApiKey: " API_KEY

  while true; do
    read -rp "请输入 NodeID（必须是数字）: " NODE_ID
    [[ "$NODE_ID" =~ ^[0-9]+$ ]] && break
    echo "❌ NodeID 必须是数字，请重新输入。"
  done
}

# -----------------------------
# 输入：Socks5 家宽代理
# -----------------------------
ask_s5_info() {
  echo "======================================"
  echo "        填写家宽 Socks5 代理信息"
  echo "======================================"
  read -rp "Socks5 地址（例：123.123.123.123）: " S5_HOST

  while true; do
    read -rp "Socks5 端口（例：1080）: " S5_PORT
    [[ "$S5_PORT" =~ ^[0-9]+$ ]] && break
    echo "❌ 端口必须是数字，请重输。"
  done

  read -rp "Socks5 用户名（可留空）: " S5_USER
  read -rsp "Socks5 密码（可留空）: " S5_PASS
  echo
}

# -----------------------------
# 写入：普通节点配置模板
# -----------------------------
write_single_templates() {
  mkdir -p "$CONFIG_DIR"

  # config.json（普通节点）
  cat <<'EOF' >"$CONFIG_DIR/config.json"
{
  "Log": { "Level": "error", "Output": "" },
  "Cores": [
    {
      "Type": "xray",
      "Log": { "Level": "error", "ErrorPath": "/etc/V2bX/error.log" },
      "OutboundConfigPath": "/etc/V2bX/custom_outbound.json",
      "RouteConfigPath": "/etc/V2bX/route.json"
    }
  ],
  "Nodes": [
    {
      "Core": "xray",
      "ApiHost": "https://gucci.weyolo.com",
      "ApiKey": "hubentuan@linux.do",
      "NodeID": 51,
      "NodeType": "vless",
      "Timeout": 30,
      "ListenIP": "0.0.0.0",
      "SendIP": "0.0.0.0",
      "DeviceOnlineMinTraffic": 200,
      "MinReportTraffic": 0,
      "EnableProxyProtocol": false,
      "EnableUot": true,
      "EnableTFO": true,
      "DNSType": "UseIPv4"
    }
  ]
}
EOF

  # 普通路由 route.json
  cat <<'EOF' >"$CONFIG_DIR/route.json"
{
  "domainStrategy": "IPOnDemand",
  "rules": [
    { "type": "field", "outboundTag": "block", "ip": [
      "geoip:private", "127.0.0.0/8", "10.0.0.0/8",
      "172.16.0.0/12", "192.168.0.0/16", "fc00::/7", "fe80::/10"
    ]},
    { "type": "field", "outboundTag": "IPv6_out", "ip": ["::/0"] },
    { "type": "field", "outboundTag": "IPv4_out", "network": "tcp,udp" }
  ]
}
EOF
}

# -----------------------------
# 写入：家宽节点配置模板
# -----------------------------
write_home_templates() {
  mkdir -p "$CONFIG_DIR"

  # config.json（家宽节点）
  cat <<'EOF' >"$CONFIG_DIR/config.json"
{
  "Log": { "Level": "error", "Output": "" },
  "Cores": [
    {
      "Type": "xray",
      "Log": { "Level": "error", "ErrorPath": "/etc/V2bX/error.log" },
      "OutboundConfigPath": "/etc/V2bX/custom_outbound.json",
      "RouteConfigPath": "/etc/V2bX/route.json"
    }
  ],
  "Nodes": [
    {
      "Core": "xray",
      "ApiHost": "https://gucci.weyolo.com",
      "ApiKey": "hubentuan@linux.do",
      "NodeID": 9,
      "NodeType": "vless",
      "Timeout": 30,
      "ListenIP": "0.0.0.0",
      "SendIP": "0.0.0.0",
      "Port": 1234,
      "EnableProxyProtocol": false,
      "EnableUot": true,
      "EnableTFO": true,
      "DNSType": "UseIPv4",
      "VlessFlow": "xtls-rprx-vision",
      "CertConfig": {
        "CertMode": "reality",
        "RejectUnknownSni": false,
        "Dest": "tesla.com:443",
        "ServerNames": ["tesla.com", "www.tesla.com"],
        "PrivateKey": "QhUmkwtRtNsq-F70B4T1-2dwvbnjHmq6oanjFLBj5hk",
        "ShortIds": ["", "fc681301"],
        "Fingerprint": "chrome"
      }
    }
  ]
}
EOF

  # 家宽路由
  cat <<'EOF' >"$CONFIG_DIR/route.json"
{
  "domainStrategy": "AsIs",
  "rules": [
    { "type": "field", "inboundTag": ["[https://gucci.weyolo.com]-vless:9"], "network": "tcp", "outboundTag": "egress_via_s5" },
    { "type": "field", "outboundTag": "block", "ip": [
      "geoip:private","127.0.0.1/32","10.0.0.0/8","fc00::/7","fe80::/10","172.16.0.0/12"
    ]},
    { "type": "field", "outboundTag": "block", "protocol": ["bittorrent"] },
    { "type": "field", "outboundTag": "direct_ipv4", "network": "tcp,udp" }
  ]
}
EOF

  # custom_outbound.json
  cat <<'EOF' >"$CONFIG_DIR/custom_outbound.json"
[
  {
    "tag": "socks5_proxy",
    "protocol": "socks",
    "settings": {
      "servers": [
        { "address": "ax.a0b.com", "port": 10246, "users": [ { "user": "u", "pass": "p" } ] }
      ]
    },
    "streamSettings": { "sockopt": { "tcpFastOpen": true } }
  },
  {
    "tag": "egress_via_s5",
    "protocol": "freedom",
    "settings": { "domainStrategy": "UseIPv4v6" },
    "streamSettings": { "sockopt": { "dialerProxy": "socks5_proxy" } }
  },
  { "tag": "direct_ipv4", "protocol": "freedom", "settings": { "domainStrategy": "UseIPv4v6" } },
  { "tag": "direct_ipv6", "protocol": "freedom", "settings": { "domainStrategy": "UseIPv6" } },
  { "protocol": "blackhole", "tag": "block" }
]
EOF
}

# -----------------------------
# 配置普通节点
# -----------------------------
setup_single() {
  ask_basic_info
  write_single_templates

  jq \
    --arg h "$API_HOST" \
    --arg k "$API_KEY" \
    --argjson n "$NODE_ID" \
    '.Nodes[0].ApiHost=$h | .Nodes[0].ApiKey=$k | .Nodes[0].NodeID=$n' \
    "$CONFIG_DIR/config.json" >"$CONFIG_DIR/config.json.tmp"

  mv "$CONFIG_DIR/config.json.tmp" "$CONFIG_DIR/config.json"

  echo "✅ 普通节点配置完成"
}

# -----------------------------
# 配置家宽S5节点
# -----------------------------
setup_home_s5() {
  ask_basic_info
  ask_s5_info
  write_home_templates

  # 替换 config.json 参数
  jq \
    --arg h "$API_HOST" \
    --arg k "$API_KEY" \
    --argjson n "$NODE_ID" \
    '.Nodes[0].ApiHost=$h | .Nodes[0].ApiKey=$k | .Nodes[0].NodeID=$n' \
    "$CONFIG_DIR/config.json" >"$CONFIG_DIR/config.json.tmp"
  mv "$CONFIG_DIR/config.json.tmp" "$CONFIG_DIR/config.json"

  # inboundTag 自动更新
  jq \
    --arg h "$API_HOST" \
    --arg n "$NODE_ID" \
    '.rules[0].inboundTag[0]=("[" + $h + "]-vless:" + $n)' \
    "$CONFIG_DIR/route.json" >"$CONFIG_DIR/route.json.tmp"
  mv "$CONFIG_DIR/route.json.tmp" "$CONFIG_DIR/route.json"

  # Socks5 填写
  if [[ -z "$S5_USER" && -z "$S5_PASS" ]]; then
    jq \
      --arg host "$S5_HOST" \
      --argjson port "$S5_PORT" \
      '.[0].settings.servers[0].address=$host
       | .[0].settings.servers[0].port=$port
       | del(.[0].settings.servers[0].users)' \
      "$CONFIG_DIR/custom_outbound.json" >"$CONFIG_DIR/custom_outbound.json.tmp"
  else
    jq \
      --arg host "$S5_HOST" \
      --argjson port "$S5_PORT" \
      --arg u "$S5_USER" \
      --arg p "$S5_PASS" \
      '.[0].settings.servers[0].address=$host
       | .[0].settings.servers[0].port=$port
       | .[0].settings.servers[0].users[0].user=$u
       | .[0].settings.servers[0].users[0].pass=$p' \
      "$CONFIG_DIR/custom_outbound.json" >"$CONFIG_DIR/custom_outbound.json.tmp"
  fi

  mv "$CONFIG_DIR/custom_outbound.json.tmp" "$CONFIG_DIR/custom_outbound.json"

  echo "✅ 家宽 S5 节点配置完成"
}

# -----------------------------
# 主菜单
# -----------------------------
menu() {
  echo "======================================"
  echo "         V2bX 后端一键配置脚本"
  echo "======================================"
  echo "  1) 配置普通 VLESS 单节点"
  echo "  2) 配置家宽 Socks5 节点"
  echo "  q) 退出脚本"
  echo "--------------------------------------"
  read -rp "请选择: " choice

  case "$choice" in
    1) setup_single ;;
    2) setup_home_s5 ;;
    q|Q) echo "已退出"; exit 0 ;;
    *) echo "❌ 无效选择"; exit 1 ;;
  esac

  echo "--------------------------------------"
  echo "配置完成！你可以重启 V2bX："
  echo "systemctl restart v2bx"
}

need_root
need_jq
menu
