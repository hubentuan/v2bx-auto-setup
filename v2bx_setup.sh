#!/usr/bin/env bash
set -euo pipefail

# ============================================
#   风萧萧 · hubentuan
#   V2bX 后端一键配置脚本（普通 / 家宽 / CDN）
#   配置目录：/etc/V2bX/
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
  # 已安装就直接跳过
  if command -v jq >/dev/null 2>&1; then
    echo "✅ 已检测到 jq，跳过安装。"
    return
  fi

  echo "⚠️ 未检测到 jq，正在尝试自动安装..."

  # 不同发行版分别尝试
  if command -v apt-get >/dev/null 2>&1; then
    echo "→ 检测到 apt-get，使用 apt-get 安装 jq..."
    apt-get update -y && apt-get install -y jq
  elif command -v apt >/dev/null 2>&1; then
    echo "→ 检测到 apt，使用 apt 安装 jq..."
    apt update -y && apt install -y jq
  elif command -v yum >/dev/null 2>&1; then
    echo "→ 检测到 yum，使用 yum 安装 jq..."
    yum install -y jq
  elif command -v dnf >/dev/null 2>&1; then
    echo "→ 检测到 dnf，使用 dnf 安装 jq..."
    dnf install -y jq
  elif command -v apk >/dev/null 2>&1; then
    echo "→ 检测到 apk，使用 apk 安装 jq..."
    apk add --no-cache jq
  elif command -v pacman >/dev/null 2>&1; then
    echo "→ 检测到 pacman，使用 pacman 安装 jq..."
    pacman -Sy --noconfirm jq
  elif command -v zypper >/dev/null 2>&1; then
    echo "→ 检测到 zypper，使用 zypper 安装 jq..."
    zypper install -y jq
  else
    echo "❌ 无法自动识别包管理器，请手动安装 jq 后重新运行本脚本。"
    echo "   例如：apt install jq  或  yum install jq"
    exit 1
  fi

  # 再检查一次是否安装成功
  if ! command -v jq >/dev/null 2>&1; then
    echo "❌ 已尝试自动安装 jq，但仍未检测到。请手动安装后重试。"
    exit 1
  fi

  echo "✅ jq 安装成功。"
}

# ========== 标题 Banner ==========

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

# ========== 交互：面板基础信息 ==========

ask_basic_info() {
  echo "======================================"
  echo "         填写面板节点信息"
  echo "======================================"
  read -rp "ApiHost（例：https://panel.example.com）: " API_HOST
  read -rp "ApiKey（面板后端 Token）: " API_KEY

  while true; do
    read -rp "NodeID（必须是数字）: " NODE_ID
    [[ "$NODE_ID" =~ ^[0-9]+$ ]] && break
    echo "❌ NodeID 必须是数字，请重新输入。"
  done
}

# ========== 交互：家宽 S5 信息 ==========

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

# ========== 交互：CDN 证书信息（提示在配置前） ==========

ask_cdn_info() {
  echo "======================================"
  echo "       CDN 模式使用说明（必读）"
  echo "======================================"
  echo "1）先在 Cloudflare 中添加你的域名，并把证书域名解析到本机 IP；"
  echo "2）在 Cloudflare 面板【DNS】页，把这个记录的小黄云先关掉（仅 DNS）；"
  echo "3）本脚本会写入 Cloudflare 邮箱 + Global API Key 到 DNSEnv；"
  echo "4）配置完成后，启动 V2bX，并在面板里按 8 查看后端日志："
  echo "   - 如果看到 ACME / 证书申请成功日志，则会在 /etc/V2bX/ 生成 fullchain.cer / cert.key；"
  echo "5）证书申请成功、节点运行稳定后，再把小黄云打开，开始走 CDN 加速。"
  echo "--------------------------------------"
  echo
  read -rp "证书域名（例：cdn.example.com）: " CERT_DOMAIN
  echo "Cloudflare DNS 自动验证需要以下信息："
  read -rp "Cloudflare 邮箱（登录 CF 的邮箱）: " CF_EMAIL
  read -rp "Cloudflare Global API Key: " CF_API_KEY
}

# ========== 模板：普通节点 ==========

write_single_templates() {
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
      "DNSType": "UseIPv4"
    }
  ]
}
EOF

  if [[ ! -f "$CONFIG_DIR/custom_outbound.json" ]]; then
    echo '{}' >"$CONFIG_DIR/custom_outbound.json"
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

# ========== 模板：CDN 节点（DNS 证书） ==========

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
        "Email": "v2bx@github.com",
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
    echo '{}' >"$CONFIG_DIR/custom_outbound.json"
  fi
}

# ========== 配置逻辑：普通节点 ==========

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

# ========== 配置逻辑：家宽节点 ==========

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

# ========== 配置逻辑：CDN 节点（DNS 证书） ==========

setup_cdn() {
  clear
  print_banner

  # 先显示 CDN 使用说明 + 证书相关输入
  ask_cdn_info

  echo
  # 再填写面板信息（ApiHost / ApiKey / NodeID）
  ask_basic_info

  # 写入基础模板
  write_cdn_templates

  # 写入面板信息
  jq \
    --arg h "$API_HOST" \
    --arg k "$API_KEY" \
    --argjson n "$NODE_ID" \
    '.Nodes[0].ApiHost=$h
     | .Nodes[0].ApiKey=$k
     | .Nodes[0].NodeID=$n' \
    "$CONFIG_DIR/config.json" >"$CONFIG_DIR/config.json.tmp"
  mv "$CONFIG_DIR/config.json.tmp" "$CONFIG_DIR/config.json"

  # 写入证书域名 + CF 邮箱 + API Key（Email 固定 v2bx@github.com）
  jq \
    --arg d "$CERT_DOMAIN" \
    --arg e "$CF_EMAIL" \
    --arg a "$CF_API_KEY" \
    '.Nodes[0].CertConfig.CertDomain = $d
     | .Nodes[0].CertConfig.DNSEnv.CLOUDFLARE_EMAIL = $e
     | .Nodes[0].CertConfig.DNSEnv.CLOUDFLARE_API_KEY = $a' \
    "$CONFIG_DIR/config.json" >"$CONFIG_DIR/config.json.tmp2"
  mv "$CONFIG_DIR/config.json.tmp2" "$CONFIG_DIR/config.json"

  echo "✅ CDN 节点配置完成（Cloudflare DNS 自动申请证书）"
  echo
  echo "下一步建议："
  echo "1）确认 CF 中该域名解析到本机 IP，且小黄云关闭；"
  echo "2）重启 V2bX 服务后，查看日志是否有证书申请成功记录；"
  echo "3）证书申请成功、节点正常工作后，再开启小黄云。"
  echo
}

# ========== 安装全局命令 fxx ==========

install_global_cmd() {
  echo "正在写入全局命令 fxx ..."

  SCRIPT_PATH="$(realpath "$0" 2>/dev/null || echo "$0")"

  cat >/usr/local/bin/fxx <<EOF
#!/usr/bin/env bash
bash "$SCRIPT_PATH"
EOF

  chmod +x /usr/local/bin/fxx

  echo "全局命令已安装：fxx"
  echo "以后可以在任意目录输入  fxx  来重新打开此面板。"
  echo
}

# ========== 主菜单 ==========

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
  echo "配置完成！你可以重启 V2bX 服务（例如）："
  echo "systemctl restart V2bX"
}

# ========== 脚本入口 ==========

need_root
need_jq
install_global_cmd
menu
