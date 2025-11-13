# v2bx-auto-setup  
### 一键安装 & 配置 V2bX 后端（支持普通节点 / 家宽S5节点）

本项目提供一个完全自动化的脚本，用于生成并写入 V2bX 后端所需的全部配置文件：

/etc/V2bX/config.json
/etc/V2bX/route.json
/etc/V2bX/custom_outbound.json

yaml
Copy code

所有模板都已经内置在脚本中，无需额外文件。

---

## ✨ 功能 Features

- 一键配置两种节点类型：
  - **普通 VLESS 单节点**
  - **家宽 Socks5 中转节点**
- 自动更新：
  - ApiHost  
  - ApiKey  
  - NodeID（自动同步 route.json + config.json）
- 家宽模式支持输入：
  - Socks5 host / port
  - 用户名 / 密码（可留空）
- 自动生成完整 JSON 配置文件  
- 兼容 Debian / Ubuntu / CentOS / AlmaLinux  

---

## 📦 使用方法 Usage

### 1. 下载脚本

```bash
wget https://raw.githubusercontent.com/hubentuan/v2bx-auto-setup/main/v2bx_setup.sh
chmod +x v2bx_setup.sh
2. 运行
bash
Copy code
sudo ./v2bx_setup.sh
3. 选择节点类型
Single Node（普通 VLESS）

Home S5 Node（家宽代理）

4. 填写信息
ApiHost

ApiKey

NodeID

家宽模式额外要求：

Socks5 地址

端口

用户名（可空）

密码（可空）

5. 重启 V2bX
bash
Copy code
systemctl restart v2bx
📁 项目结构
Copy code
v2bx_setup.sh
README.md
LICENSE
📝 License
MIT License

yaml
Copy code

---

# 🎯 **3. LICENSE（MIT）**

随便放，可复制：

```txt
MIT License
Copyright (c) 

Permission is hereby granted, free of charge, to any person obtaining a copy
...
