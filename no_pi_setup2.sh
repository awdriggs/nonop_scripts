#!/bin/bash
# Hardcoded setup for Raspberry Pi Zero (Bookworm + NetworkManager)
# Usage: sudo ./setup.sh BOARD_NAME

set -e

if [ "$EUID" -ne 0 ]; then
  echo "Run as root (use sudo)" >&2
  exit 1
fi

if [ $# -ne 1 ]; then
  echo "Usage: $0 BOARD_NAME" >&2
  exit 1
fi

BOARD_NAME="$1"

# --- Hardcoded Wi-Fi credentials ---
SSID1="noWifi"
PSK1="non-optimal-cameras"

SSID2="awd"
PSK2="swindle-mars-sleeps"

# --- Set hostname ---
hostnamectl set-hostname "$BOARD_NAME"
sed -i "s/127\.0\.1\.1.*/127.0.1.1 $BOARD_NAME/" /etc/hosts

# --- Update OS and install system packages ---
apt update && apt full-upgrade -y

apt install -y \
  git vim \
  python3-pip \
  network-manager \
  python3-pil \
  python3-numpy \
  python3-gpiozero \
  python3-rpi.gpio \
  python3-picamera2   

# --- Remove strict GPIO backend (causes 'GPIO busy') ---
apt remove -y python3-rpi-lgpio || true

# --- Install Blinka and display support (system-wide install) ---
sudo pip3 install adafruit-blinka==8.56.0 --break-system-packages
sudo pip3 install adafruit-circuitpython-rgb-display --break-system-packages

# --- Enable SPI if not already enabled ---
CONFIG_FILE="/boot/firmware/config.txt"

if ! grep -q "^dtparam=spi=on" "$CONFIG_FILE"; then
  echo "Enabling SPI in $CONFIG_FILE"
  echo "dtparam=spi=on" >> "$CONFIG_FILE"
else
  echo "SPI already enabled in $CONFIG_FILE"
fi

# --- Enable and start NetworkManager ---
systemctl enable NetworkManager.service
systemctl start NetworkManager.service

# --- Configure Wi-Fi ---

nmcli connection add type wifi ifname wlan0 con-name "$SSID1" ssid "$SSID1"
nmcli connection modify "$SSID1" wifi-sec.key-mgmt wpa-psk wifi-sec.psk "$PSK1"

nmcli connection add type wifi ifname wlan0 con-name "$SSID2" ssid "$SSID2"
nmcli connection modify "$SSID2" wifi-sec.key-mgmt wpa-psk wifi-sec.psk "$PSK2"

# --- Clone project repo ---
su - awd -c "git clone https://github.com/awdriggs/non_optimal_imaging.git || true"

# --- Expand root filesystem (just in case) ---
/lib/systemd/systemd-growfs / || true

echo "✅ Setup complete for $BOARD_NAME. Reboot now."

