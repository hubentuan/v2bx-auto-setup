---

# ✅ **项目介绍**



---

```markdown
# v2bx-auto-setup  
一键安装 & 配置 V2bX 后端（支持普通节点 / 家宽 S5 节点）

本项目提供一个完全自动化的脚本，用于生成并写入 V2bX 后端所需的全部配置文件：

```

/etc/V2bX/config.json
/etc/V2bX/route.json
/etc/V2bX/custom_outbound.json

````

所有模板均已内置，无需额外文件。

---

## 📦 1. 下载脚本

```bash
wget https://raw.githubusercontent.com/hubentuan/v2bx-auto-setup/main/v2bx_setup.sh
chmod +x v2bx_setup.sh
````

---

## ▶️ 2. 运行脚本

```bash
sudo ./v2bx_setup.sh
```

---

## 🔧 3. 选择节点类型

* **Single Node（普通 VLESS）**
* **Home S5 Node（家宽代理）**

---

## ✏️ 4. 填写信息

### 基本信息（两种模式都需要）：

* ApiHost
* ApiKey
* NodeID

### 家宽代理模式额外填写：

* Socks5 地址
* 端口
* 用户名（可空）
* 密码（可空）

---

## ♻️ 5. 重启 V2bX

```bash
systemctl restart v2bx
```

---

## 📁 项目结构

```
v2bx_setup.sh
README.md
```

---

