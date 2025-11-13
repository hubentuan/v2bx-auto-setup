#!/usr/bin/env bash
set -euo pipefail

# ============================================
#   V2bX 后端一键配置脚本（含通用 DNS）
#   写入目录：/etc/V2bX/
#   所有真实 ApiHost / ApiKey 由用户输入
# ============================================

CONFIG_DIR="/etc/V2bX"

need_root() {
  if [[ "$(id -u)" -ne 0 ]]; then
    echo "❌ 本脚本需要 root 权限，请使用 sudo 运行！"
    exit 1
  fi
}

need_jq() {
  if ! command -v jq >/dev/null 2>&1; then
    echo "❌ 未检测到 jq，请先安装："
    echo "   apt install jq   或   yum install jq"
    exit 1
  fi
}

ask_basic_info() {
  echo "======================================"
  echo "         填写节点面板信息"
  echo "======================================"
  read -rp "请输入 ApiHost（例：https://panel.example.com）: " API_HOST
  read -rp "请输入 ApiKey: " API_KEY

  while true; do
    read -rp "请输入 NodeID（必须是数字）: " NODE_ID
    [[ "$NODE_ID" =~ ^[0-9]+$ ]] && break
    echo "❌ NodeID 必须是数字，请重新输入。"
  done
}

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
# 写入通用 DNS 配置 /etc/V2bX/dns.json
# 所有节点通用
# -----------------------------
write_dns_template() {
  mkdir -p "$CONFIG_DIR"

  cat <<'EOF' >"$CONFIG_DIR/dns.json"
{
  "servers": [
    {
      "address": "https://1.0.0.1/dns-query",
      "domains": [
        "geosite:geolocation-!cn"
      ],
      "expectIPs": [
        "geoip:!cn"
      ],
      "skipFallback": true
    },
    {
      "address": "8.8.8.8",
      "domains": [
        "geosite:geolocation-!cn"
      ],
      "expectIPs": [
        "geoip:!cn"
      ]
    },
    {
      "address": "9.9.9.9",
      "domains": [
        "geosite:geolocation-!cn"
      ],
      "expectIPs": [
        "geoip:!cn"
      ]
    },
    {
      "address": "223.5.5.5",
      "domains": [
        "geosite:cn",
        "geosite:apple-cn",
        "geosite:microsoft@cn"
      ],
      "expectIPs": [
        "geoip:cn"
      ]
    },
    {
      "address": "119.29.29.29",
      "domains": [
        "geosite:cn"
      ],
      "expectIPs": [
        "geoip:cn"
      ]
    },
    "localhost"
  ],
  "hosts": {
    "dns.google": [
      "8.8.8.8"
    ],
    "cloudflare-dns.com": [
      "1.0.0.1"
    ]
  },
  "queryStrategy": "UseIPv4",
  "disableCache": false,
  "disableFallback": true,
  "tag": "dns_inbound"
}
EOF
}

# -----------------------------
# 写入：普通节点配置模板
# ApiHost / ApiKey / NodeID 为占位，后面用 jq 覆盖
# -----------------------------
write_single_templates() {
  mkdir -p "$CONFIG_DIR"

  # 通用 DNS（普通节点也需要）
  write_dns_template

  # config.json（普通节点）
  cat <<'EOF' >"$CONFIG_DIR/config.json"
{
  "Log": { "Level": "error", "Output": "" },
  "Cores": [
    {
      "Type": "xray",
      "Log": { "Level": "error", "ErrorPath": "/etc/V2bX/error.log" },
      "OutboundConfigPath": "/etc/V2bX/custom_outbound.json",
      "RouteConfigPath": "/etc/V2bX/route.json",
      "DNSConfigPath": "/etc/V2bX/dns.json"
    }
  ],
  "Nodes": [
    {
      "Core": "xray",
      "ApiHost": "https://example.com",
      "ApiKey": "",
      "NodeID": 1,
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

  # 普通路由（与面板无关，不含敏感信息）
  cat <<'EOF' >"$CONFIG_DIR/route.json"
{
  "domainStrategy": "IPOnDemand",
  "rules": [
    {
      "type": "field",
      "outboundTag": "block",
      "ip": [
        "geoip:private",
        "127.0.0.0/8",
        "10.0.0.0/8",
        "172.16.0.0/12",
        "192.168.0.0/16",
        "fc00::/7",
        "fe80::/10"
      ]
    },
    {
      "type": "field",
      "outboundTag": "IPv6_out",
      "ip": [
        "::/0"
      ]
    },
    {
      "type": "field",
      "outboundTag": "IPv4_out",
      "network": "tcp,udp"
    }
  ]
}
EOF

  # 给普通节点一个空的 custom_outbound.json（防止路径报错）
  if [[ ! -f "$CONFIG_DIR/custom_outbound.json" ]]; then
    echo '{}' > "$CONFIG_DIR/custom_outbound.json"
  fi
}

# -----------------------------
# 写入：家宽节点配置模板
# 同样不包含真实 ApiHost / ApiKey
# -----------------------------
write_home_templates() {
  mkdir -p "$CONFIG_DIR"

  # 通用 DNS（家宽节点同样需要）
  write_dns_template

  # config.json（家宽节点）
  cat <<'EOF' >"$CONFIG_DIR/config.json"
{
  "Log": { "Level": "error", "Output": "" },
  "Cores": [
    {
      "Type": "xray",
      "Log": { "Level": "error", "ErrorPath": "/etc/V2bX/error.log" },
      "OutboundConfigPath": "/etc/V2bX/custom_outbound.json",
      "RouteConfigPath": "/etc/V2bX/route.json",
      "DNSConfigPath": "/etc/V2bX/dns.json"
    }
  ],
  "Nodes": [
    {
      "Core": "xray",
      "ApiHost": "https://example.com",
      "ApiKey": "",
      "NodeID": 1,
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
        "Dest": "example.com:443",
        "ServerNames": [
          "example.com"
        ],
        "PrivateKey": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
        "ShortIds": [
          ""
        ],
        "Fingerprint": "chrome"
      }
    }
  ]
}
EOF

  # 家宽路由（inboundTag 用占位，后面根据 ApiHost + NodeID 重写）
  cat <<'EOF' >"$CONFIG_DIR/route.json"
{
  "domainStrategy": "AsIs",
  "rules": [
    {
      "type": "field",
      "inboundTag": [
        "[https://example.com]-vless:1"
      ],
      "network": "tcp",
      "outboundTag": "egress_via_s5"
    },
    {
      "type": "field",
      "outboundTag": "block",
      "ip": [
        "geoip:private",
        "127.0.0.1/32",
        "10.0.0.0/8",
        "fc00::/7",
        "fe80::/10",
        "172.16.0.0/12"
      ]
    },
    {
      "type": "field",
      "outboundTag": "block",
      "protocol": [
        "bittorrent"
      ]
    },
    {
      "type": "field",
      "outboundTag": "direct_ipv4",
      "network": "tcp,udp"
    }
  ]
}
EOF

  # custom_outbound.json（Socks5 占位，后面用用户输入覆盖）
  cat <<'EOF' >"$CONFIG_DIR/custom_outbound.json"
[
  {
    "tag": "socks5_proxy",
    "protocol": "socks",
    "settings": {
      "servers": [
        {
          "address": "s5.example.com",
          "port": 1080,
          "users": [
            {
              "user": "user",
              "pass": "pass"
            }
          ]
        }
      ]
    },
    "streamSettings": {
      "sockopt": {
        "tcpFastOpen": true
      }
    }
  },
  {
    "tag": "egress_via_s5",
    "protocol": "freedom",
    "settings": {
      "domainStrategy": "UseIPv4v6"
    },
    "streamSettings": {
      "sockopt": {
        "dialerProxy": "socks5_proxy"
      }
    }
  },
  {
    "tag": "direct_ipv4",
    "protocol": "freedom",
    "settings": {
      "domainStrategy": "UseIPv4v6"
    }
  },
  {
    "tag": "direct_ipv6",
    "protocol": "freedom",
    "settings": {
      "domainStrategy": "UseIPv6"
    }
  },
  {
    "protocol": "blackhole",
    "tag": "block"
  }
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
    '.Nodes[0].ApiHost=$h
     | .Nodes[0].ApiKey=$k
     | .Nodes[0].NodeID=$n' \
    "$CONFIG_DIR/config.json" >"$CONFIG_DIR/config.json.tmp"

  mv "$CONFIG_DIR/config.json.tmp" "$CONFIG_DIR/config.json"

  echo "✅ 普通节点配置完成"
}

# -----------------------------
# 配置家宽 S5 节点
# -----------------------------
setup_home_s5() {
  ask_basic_info
  ask_s5_info
  write_home_templates

  # 覆盖 config.json 的 ApiHost / ApiKey / NodeID
  jq \
    --arg h "$API_HOST" \
    --arg k "$API_KEY" \
    --argjson n "$NODE_ID" \
    '.Nodes[0].ApiHost=$h
     | .Nodes[0].ApiKey=$k
     | .Nodes[0].NodeID=$n' \
    "$CONFIG_DIR/config.json" >"$CONFIG_DIR/config.json.tmp"
  mv "$CONFIG_DIR/config.json.tmp" "$CONFIG_DIR/config.json"

  # route.json 中 inboundTag 跟随 ApiHost + NodeID
  jq \
    --arg h "$API_HOST" \
    --arg n "$NODE_ID" \
    '.rules[0].inboundTag[0]=("[" + $h + "]-vless:" + $n)' \
    "$CONFIG_DIR/route.json" >"$CONFIG_DIR/route.json.tmp"
  mv "$CONFIG_DIR/route.json.tmp" "$CONFIG_DIR/route.json"

  # custom_outbound.json 中写入 Socks5 信息
  if [[ -z "$S5_USER" && -z "$S5_PASS" ]]; then
    # 无账号密码，删除 users 字段
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

