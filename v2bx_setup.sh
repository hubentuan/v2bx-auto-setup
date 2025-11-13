#!/usr/bin/env bash
set -euo pipefail

# ============================================
#   风萧萧 · hubentuan
#   V2bX 后端一键配置脚本（普通 / 家宽 / CDN）
#   写入目录：/etc/V2bX/
# ============================================

CONFIG_DIR="/etc/V2bX"

# ========== 基础检查 ==========

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

# ========== 交互部分 ==========

ask_basic_info() {
  echo "======================================"
  echo "         填写面板节点信息"
  echo "======================================"
  read -rp "ApiHost（例：https://panel.example.com）: " API_HOST
  read -rp "ApiKey: " API_KEY

  while true; do
    read -rp "NodeID（必须是数字）: " NODE_ID
    [[ "$NODE_ID" =~ ^[0-9]+$ ]] && break
    echo "❌ NodeID 必须是数字，请重新输入。"
  done
}

ask_s5_info() {
  echo "======================================"
  echo "        填写家宽 Socks5 代理信息"
  echo "======================================"
  read -rp "Socks5 地址（例：123.123.123.123 或 域名）: " S5_HOST

  while true; do
    read -rp "Socks5 端口（例：1080）: " S5_PORT
    [[ "$S5_PORT" =~ ^[0-9]+$ ]] && break
    echo "❌ 端口必须是数字，请重输。"
  done

  read -rp "Socks5 用户名（可留空）: " S5_USER
  read -rsp "Socks5 密码（可留空）: " S5_PASS
  echo
}

ask_cdn_info() {
  echo "======================================"
  echo "          填写 CDN 证书信息"
  echo "======================================"
  read -rp "证书域名（例：cdn.example.com）: " CERT_DOMAIN
  echo "下面填写 Cloudflare 账号信息，用于 DNS 自动验证证书："
  read -rp "Cloudflare 邮箱: " CF_EMAIL
  read -rp "Cloudflare Global API Key: " CF_API_KEY

  echo
  echo "【重要操作提示】"
  echo "1）先在 Cloudflare 中添加你的域名，并把上面的证书域名解析到本机 IP；"
  echo "2）先关闭小黄云（仅 DNS 解析，不代理）；"
  echo "3）启动 V2bX 后，在面板中按 8 查看日志，等待证书申请成功；"
  echo "4）看到证书申请成功、节点正常工作后，再重新打开小黄云（开启 CDN）。"
  echo
}

# ========== 公用 DNS（所有模式通用） ==========

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

# ========== 路由 ==========

# 普通节点 + CDN 共用
write_common_route() {
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
}

# 家宽专用
write_home_route() {
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
}

# ========== 模板：普通节点 ==========

write_single_templates() {
  mkdir -p "$CONFIG_DIR"
  write_dns_template
  write_common_route

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

  if [[ ! -f "$CONFIG_DIR/custom_outbound.json" ]]; then
    echo '{}' > "$CONFIG_DIR/custom_outbound.json"
  fi
}

# ========== 模板：家宽节点 ==========

write_home_templates() {
  mkdir -p "$CONFIG_DIR"
  write_dns_template
  write_home_route

  cat <<'EOF' >"$CONFIG_DIR/config.json"
{
  "Log": {
    "Level": "error",
    "Output": ""
  },
  "Cores": [
    {
      "Type": "xray",
      "Log": {
        "Level": "error",
        "ErrorPath": "/etc/V2bX/error.log"
      },
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
      "EnableProxyProtocol": false,
      "EnableUot": true,
      "EnableTFO": true,
      "DNSType": "UseIPv4"
    }
  ]
}
EOF

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

# ========== 模板：CDN 节点（DNS 验证证书） ==========

write_cdn_templates() {
  mkdir -p "$CONFIG_DIR"
  write_dns_template
  write_common_route

  cat <<'EOF' >"$CONFIG_DIR/config.json"
{
  "Log": {
    "Level": "error",
    "Output": ""
  },
  "Cores": [
    {
      "Type": "xray",
      "Log": {
        "Level": "error",
        "ErrorPath": "/etc/V2bX/error.log"
      },
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
      "DNSType": "UseIPv4",
      "CertConfig": {
        "CertMode": "dns",
        "RejectUnknownSni": false,
        "CertDomain": "cdn.example.com",
        "CertFile": "/etc/V2bX/fullchain.cer",
        "KeyFile": "/etc/V2bX/cert.key",
        "Email": "",
        "Provider": "cloudflare",
        "DNSEnv": {
          "CLOUDFLARE_EMAIL": "",
          "CLOUDFLARE_API_KEY": ""
        }
      }
    }
  ]
}
EOF

  if [[ ! -f "$CONFIG_DIR/custom_outbound.json" ]]; then
    echo '{}' > "$CONFIG_DIR/custom_outbound.json"
  fi
}

# ========== 具体配置逻辑 ==========

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

  echo "✅ 普通 VLESS 节点配置完成"
}

setup_home_s5() {
  ask_basic_info
  ask_s5_info
  write_home_templates

  jq \
    --arg h "$API_HOST" \
    --arg k "$API_KEY" \
    --argjson n "$NODE_ID" \
    '.Nodes[0].ApiHost=$h
     | .Nodes[0].ApiKey=$k
     | .Nodes[0].NodeID=$n' \
    "$CONFIG_DIR/config.json" >"$CONFIG_DIR/config.json.tmp"
  mv "$CONFIG_DIR/config.json.tmp" "$CONFIG_DIR/config.json"

  jq \
    --arg h "$API_HOST" \
    --arg n "$NODE_ID" \
    '.rules[0].inboundTag[0]=("[" + $h + "]-vless:" + $n)' \
    "$CONFIG_DIR/route.json" >"$CONFIG_DIR/route.json.tmp"
  mv "$CONFIG_DIR/route.json.tmp" "$CONFIG_DIR/route.json"

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

  echo "✅ 家宽 Socks5 节点配置完成"
}

setup_cdn() {
  ask_basic_info
  ask_cdn_info
  write_cdn_templates

  # 面板信息
  jq \
    --arg h "$API_HOST" \
    --arg k "$API_KEY" \
    --argjson n "$NODE_ID" \
    '.Nodes[0].ApiHost=$h
     | .Nodes[0].ApiKey=$k
     | .Nodes[0].NodeID=$n' \
    "$CONFIG_DIR/config.json" >"$CONFIG_DIR/config.json.tmp"
  mv "$CONFIG_DIR/config.json.tmp" "$CONFIG_DIR/config.json"

  # 证书域名 + CF 邮箱 + API Key
  jq \
    --arg d "$CERT_DOMAIN" \
    --arg e "$CF_EMAIL" \
    --arg a "$CF_API_KEY" \
    '.Nodes[0].CertConfig.CertDomain = $d
     | .Nodes[0].CertConfig.Email = $e
     | .Nodes[0].CertConfig.DNSEnv.CLOUDFLARE_EMAIL = $e
     | .Nodes[0].CertConfig.DNSEnv.CLOUDFLARE_API_KEY = $a' \
    "$CONFIG_DIR/config.json" >"$CONFIG_DIR/config.json.tmp2"
  mv "$CONFIG_DIR/config.json.tmp2" "$CONFIG_DIR/config.json"

  echo "✅ CDN 节点配置完成（DNS 自动验证证书）"
  echo
  echo "请按以下步骤操作："
  echo "1）确认证书域名已在 Cloudflare 解析到本机 IP；"
  echo "2）小黄云保持关闭状态（仅 DNS）；"
  echo "3）启动 V2bX 后，在面板中按 8 查看日志，等待证书申请成功；"
  echo "4）证书正常签发后，再开启小黄云进行 CDN 加速。"
  echo
}

# ========== 界面 Banner ==========

print_banner() {
  echo -e "\e[38;5;118m"
  cat <<'EOF'
╔══════════════════════════════════════╗
║    Feng Xiao Xiao · 风萧萧 公益节点   ║
║          V2bX Backend Auto Setup     ║
║              by hubentuan            ║
╚══════════════════════════════════════╝
EOF
  echo -e "\e[0m"
}

# ========== 主菜单 ==========

print_banner() {
  echo -e "\e[38;5;118m"
  cat <<'EOF'
╔════════════════════════════════════════════════════════════════════╗
║                    Feng Xiao Xiao · 风萧萧 公益节点                ║
║                       V2bX Backend Auto Setup                      ║
║                             by hubentuan                           ║
╚════════════════════════════════════════════════════════════════════╝
EOF
  echo -e "\e[0m"
}

# 写入全局命令 fxx，方便随时呼出此面板
install_global_cmd() {
  echo "正在写入全局命令 fxx ..."

  # 当前脚本的绝对路径
  SCRIPT_PATH="$(realpath "$0" 2>/dev/null || echo "$0")"

  cat >/usr/local/bin/fxx <<EOF
#!/usr/bin/env bash
bash "$SCRIPT_PATH"
EOF

  chmod +x /usr/local/bin/fxx

  echo "全局命令已安装：fxx"
  echo "以后在任意目录输入 fxx 就可以重新打开这个面板。"
  echo
}

menu() {
  clear
  print_banner
  echo "======================================"
  echo "           V2bX 后端一键配置脚本"
  echo "======================================"
  echo "  1) 配置普通 VLESS 单节点"
  echo "  2) 配置家宽 Socks5 节点"
  echo "  3) 配置 CDN 节点（Cloudflare DNS 证书）"
  echo "  q) 退出脚本"
  echo "--------------------------------------"
  read -rp "请选择: " choice

  case "$choice" in
    1) setup_single ;;
    2) setup_home_s5 ;;
    3) setup_cdn ;;
    q|Q) echo "已退出"; exit 0 ;;
    *) echo "❌ 无效选择"; exit 1 ;;
  esac

  echo "--------------------------------------"
  echo "配置完成！你可以重启 V2bX："
  echo "systemctl restart v2bx-core"
}

need_root
need_jq
install_global_cmd
menu
