# 🔐 Secure VPS Bootstrap

A secure and interactive bash script to automate the initial setup of a VPS — including UFW, Fail2Ban, SSH hardening, SSH key management, and Bitwarden integration.

---

## ✨ Features

- ✅ Update & upgrade system packages
- 🔐 UFW setup with SSH port detection
- 🛡️ Fail2Ban auto-configuration
- 🔑 SSH key generation and authorized key setup
- 📄 Bitwarden CLI integration for secure private key storage
- ⚙️ System hardening via `sysctl.conf`
- 🧠 loginctl linger setup for persistent user services

---

## 🚀 Usage

### 1. Clone this repo and give permission:

```bash
git clone https://github.com/yourusername/secure-vps-bootstrap.git
cd secure-vps-bootstrap
chmod +x vps-setup.sh
```

### 2. Run the script

```bash
./vps-setup.sh
```

---

## 📦 Requirements

- Ubuntu 20.04/22.04
- sudo privileges
- Optional: Bitwarden account & CLI (`snap install bw`)

---

## 📁 Structure

```
.
├── vps-setup.sh       # Main automation script
└── README.md          # This file
```

---

## 📄 License

MIT License
