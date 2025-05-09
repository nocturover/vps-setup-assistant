#!/bin/bash

# VPS 자동화 설치 도구
# by seojun

SSH_CONFIG="/etc/ssh/sshd_config"
AUTHORIZED_KEYS="$HOME/.ssh/authorized_keys"
SSH_DIR="$HOME/.ssh"
KEY_NAME="id_rsa"

pause() {
  read -rp "계속하려면 [Enter] 키를 누르세요..."
}

show_menu() {
  clear
  echo "===== VPS 자동화 도구 ====="
  echo "1. 시스템 업데이트 및 필수 패키지 설치"
  echo "2. SSH 설정 가이드 제공"
  echo "3. Fail2Ban 자동 설정"
  echo "4. UFW 설정 (포트 감지 및 안내 포함)"
  echo "5. SSH 키 생성 및 등록"
  echo "6. Bitwarden 설치 및 키 저장"
  echo "7. loginctl linger 설정"
  echo "8. sysctl.conf 커널 보안 설정"
  echo "9. 종료"
  echo "==========================="
}

update_system() {
  echo "[+] 시스템 업데이트 중..."
  sudo apt update && sudo apt upgrade -y

  echo "[+] UFW 설치 확인..."
  if ! command -v ufw &>/dev/null; then
    sudo apt install ufw -y
  fi

  echo "[+] Fail2Ban 설치 확인..."
  if ! command -v fail2ban-client &>/dev/null; then
    sudo apt install fail2ban -y
  fi

  pause
}

ssh_guide() {
  echo "[!] 민감한 SSH 설정입니다."
  echo "현재 SSH 설정 파일 위치: $SSH_CONFIG"
  echo "SSH 설정 예시:"
  echo " - Port 1234"
  echo " - PermitRootLogin no"
  echo " - PasswordAuthentication no"
  echo
  echo "설정 완료 후 아래 명령어로 SSH 재시작 필요:"
  echo "  sudo systemctl restart sshd"
  pause
}

fail2ban_setup() {
  echo "[+] Fail2Ban 기본 설정 적용 중..."
  sudo tee /etc/fail2ban/jail.local >/dev/null <<EOF
[sshd]
enabled = true
port = ssh
logpath = /var/log/auth.log
backend = systemd
maxretry = 5
bantime = 3600
EOF

  sudo systemctl enable fail2ban
  sudo systemctl restart fail2ban
  echo "[+] Fail2Ban 설정 완료"
  pause
}

ufw_setup() {
  echo "[+] UFW 설정 시작..."

  SSH_PORT=$(grep -Ei '^Port' "$SSH_CONFIG" | awk '{print $2}')
  echo "[+] SSH 포트 감지됨: $SSH_PORT"

  read -rp "UFW에서 SSH 포트 $SSH_PORT 를 허용하시겠습니까? (y/n): " ssh_allow
  if [[ $ssh_allow == "y" ]]; then
    sudo ufw allow "$SSH_PORT"
  fi

  while true; do
    read -rp "추가로 허용할 포트 (예: 80,443) 입력 (없으면 Enter): " port
    [[ -z "$port" ]] && break
    sudo ufw allow "$port"
  done

  sudo ufw enable
  echo "[+] UFW 활성화 완료"

  echo
  echo "[!] AWS/Vultr 사용 시, 포털에서 해당 포트들이 inbound rule에 추가돼야 합니다."
  pause
}

ssh_keygen_and_register() {
  mkdir -p "$SSH_DIR"
  chmod 700 "$SSH_DIR"

  if [[ -f "$SSH_DIR/$KEY_NAME" ]]; then
    echo "[!] 기존 SSH 키가 존재합니다: $SSH_DIR/$KEY_NAME"
  else
    ssh-keygen -t rsa -b 4096 -f "$SSH_DIR/$KEY_NAME" -N ""
    echo "[+] SSH 키 생성 완료"
  fi

  cat "$SSH_DIR/${KEY_NAME}.pub" >> "$AUTHORIZED_KEYS"
  chmod 600 "$AUTHORIZED_KEYS"

  echo "[+] public key 등록 완료"
  echo
  echo "[!] 다음 private key를 복사해 안전한 장소에 저장하세요:"
  echo "========== BEGIN PRIVATE KEY =========="
  cat "$SSH_DIR/$KEY_NAME"
  echo "=========== END PRIVATE KEY ==========="

  pause
}

bitwarden_setup() {
  read -rp "Bitwarden CLI를 snap으로 설치할까요? (y/n): " bw_install
  if [[ $bw_install == "y" ]]; then
    sudo snap install bw
  fi

  echo
  echo "[!] Bitwarden CLI 사용법:"
  echo "  bw login"
  echo "  bw unlock --raw"
  echo "  bw sync"
  pause

  read -rp "Bitwarden에 SSH 프라이빗 키를 저장할까요? (y/n): " bw_save
  if [[ $bw_save == "y" ]]; then
    read -rp "서버 별명 입력 (예: aws_ec2): " server_alias
    USERNAME=$(whoami)
    SERVER_IP=$(curl -s ifconfig.me)
    PORT=$(grep -Ei '^Port' "$SSH_CONFIG" | awk '{print $2}')

    ITEM_NAME="${server_alias}_${USERNAME}_${SERVER_IP}_${PORT}"

    bw create item --name "$ITEM_NAME" --type "secureNote" --notes "$(cat "$SSH_DIR/$KEY_NAME")"
    echo "[+] Bitwarden에 저장 완료: $ITEM_NAME"
  fi

  pause
}

# 7. loginctl linger 설정
enable_linger() {
  echo "[🧠 설명] loginctl linger는 사용자가 로그인하지 않아도 systemd user 서비스가 실행될 수 있도록 허용합니다."
  echo "[💡 활용 예] JupyterLab, vncserver, PM2 등 백그라운드 서비스 자동 실행"
  echo
  read -rp "현재 사용자에 대해 linger를 활성화하시겠습니까? (y/n): " linger
  if [[ $linger == "y" ]]; then
    sudo loginctl enable-linger "$USER"
    echo "[+] linger 활성화 완료"
  else
    echo "[!] linger 설정을 건너뜁니다."
  fi
  pause
}

# 8. sysctl 하드닝
harden_sysctl() {
  echo "[🧠 설명] sysctl은 커널 수준에서 보안 설정을 강화합니다."
  echo " - net.ipv4.tcp_syncookies = 1 : SYN flood 공격 방어"
  echo " - icmp_echo_ignore_broadcasts = 1 : broadcast ping 무시"
  echo " - rp_filter = 1 : IP spoofing 방지"
  echo

  read -rp "해당 보안 설정을 적용하시겠습니까? (y/n): " apply_sysctl
  if [[ $apply_sysctl == "y" ]]; then
    sudo tee -a /etc/sysctl.conf >/dev/null <<EOF

# 보안 하드닝 설정 (자동 추가)
net.ipv4.tcp_syncookies = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.accept_source_route = 0
EOF

    sudo sysctl -p
    echo "[+] 커널 보안 설정 적용 완료"
  else
    echo "[!] sysctl 설정을 건너뜁니다."
  fi
  pause
}

# 메인 루프
while true; do
  show_menu
  read -rp "번호 선택: " choice
  case $choice in
    1) update_system ;;
    2) ssh_guide ;;
    3) fail2ban_setup ;;
    4) ufw_setup ;;
    5) ssh_keygen_and_register ;;
    6) bitwarden_setup ;;
    7) enable_linger ;;
    8) harden_sysctl ;;
    9) echo "종료합니다."; break ;;
    *) echo "잘못된 입력입니다."; pause ;;
  esac
done

