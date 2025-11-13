---

# **v2bx-auto-setup 项目说明**

本项目提供一个自动化脚本，用于生成并写入 V2bX 后端所需的全部配置文件：

* /etc/V2bX/config.json
* /etc/V2bX/route.json
* /etc/V2bX/custom_outbound.json

所有模板均已内置于脚本中，无需提供额外文件。

---

## **1. 下载脚本**

```bash
wget https://raw.githubusercontent.com/hubentuan/v2bx-auto-setup/main/v2bx_setup.sh
chmod +x v2bx_setup.sh
```

---

## **2. 运行脚本**

```bash
sudo ./v2bx_setup.sh
```

---

## **3. 选择节点类型**

* 普通 VLESS 单节点
* 家宽 Socks5 节点

---

## **4. 填写节点信息**

脚本会要求填写：

* ApiHost
* ApiKey
* NodeID

家宽模式额外需要填写：

* Socks5 地址
* Socks5 端口
* Socks5 用户名（可留空）
* Socks5 密码（可留空）

---

## **5. 重启 V2bX**

```bash
systemctl restart v2bx
```

---

## **6. 项目文件结构**

```
v2bx_setup.sh
README.md
```

---


告诉我，我马上给你改。
