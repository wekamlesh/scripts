# 🛠️ Debian Server Setup Script

![Setup Script](https://img.shields.io/badge/Setup-Script-blue.svg)
![Shell Script](https://img.shields.io/badge/Language-Bash-orange.svg)
![Fail2Ban](https://img.shields.io/badge/Security-Fail2Ban-red.svg)

## 📌 Overview

This repository contains a **simple Debian server setup script** that:

- Updates and upgrades the system
- Installs essential packages
- Sets the timezone
- Enables unattended upgrades
- Adds brute-force protection using Fail2Ban
- Creates a user `sammy` with sudo privileges
- Allows SSH key login for the new user

---

## ⚙️ Features

- 🆕 System update & upgrade
- 📦 Core tools installed
- 🌍 Timezone configured
- 🔐 Fail2Ban for basic SSH brute-force protection
- 🧑‍💻 User creation with SSH key setup
- 🔑 SSH key copy from local machine
- 🛡️ Unattended upgrades enabled

---

## 🚀 Getting Started

### 1. Run the setup script

Run the script on your Debian server:

```bash
curl -fsSL https://raw.githubusercontent.com/wekamlesh/scripts/main/setup.sh | sudo bash
```

---

## 👤 Add User Sammy and SSH Access

### ✅ Create the user

```bash
sudo adduser sammy
```

You will be prompted to enter a password and some optional info.

### ✅ Give sammy sudo access

```bash
sudo usermod -aG sudo sammy
```

---

## 📡 Copy your SSH public key

From your local machine, run:

```bash
ssh-copy-id sammy@YOUR_SERVER_IP
```

If your public key is in a custom location:

```bash
ssh-copy-id -i ~/.ssh/YOUR_KEY.pub sammy@YOUR_SERVER_IP
```

### Test SSH login

```bash
ssh sammy@YOUR_SERVER_IP
```

You should be logged in with SSH key authentication (no password prompt).

---

## 🛡️ Optional Security Enhancement

Once SSH login works with keys, you can disable password authentication:

### 1. Edit SSH config

```bash
sudo nano /etc/ssh/sshd_config
```

### 2. Set password authentication to no

```bash
PasswordAuthentication no
```

### 3. Restart SSH service

```bash
sudo systemctl restart ssh
```

---

## 📝 License

This project is open source and available under the [MIT License](LICENSE).

## 🤝 Contributing

Contributions, issues, and feature requests are welcome!

## 📧 Contact

For questions or support, please open an issue in this repository.
