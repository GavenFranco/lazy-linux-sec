#!/bin/bash
# secscript for linux 
# By Gaven Franco

# Function to check if the user is running as root
check_root() {
  if [[ $EUID -ne 0 ]]; then
    echo "Please run this script as root."
    exit 1
  fi
}

# Function to update the system
update_system() {
  echo "Updating package repositories..."
  apt-get update -y > /dev/null

  echo "Upgrading installed packages..."
  apt-get upgrade -y > /dev/null

  echo "Performing distribution upgrade..."
  apt-get dist-upgrade -y > /dev/null

  echo "System updated successfully!"
}

# Function to set up the firewall
setup_firewall() {
  echo "Installing UFW..."
  apt-get install ufw -y > /dev/null

  echo "Enabling UFW..."
  ufw enable
  echo "UFW is enabled."
  ufw status
}

# Function to delete or modify user accounts
manage_users() {
  echo "Enter user account names, separated by spaces:"
  read -a users

  for user in "${users[@]}"; do
    echo "Do you want to delete $user? (yes or no)"
    read yn1
    if [ "$yn1" == "yes" ]; then
      userdel -r "$user"
      echo "$user has been deleted."
    else
      echo "Make $user an administrator? (yes or no)"
      read yn2
      if [ "$yn2" == "yes" ]; then
        groups=("sudo" "adm" "lpadmin" "sambashare")
        for group in "${groups[@]}"; do
          gpasswd -a "$user" "$group"
        done
        echo "$user has been made an administrator."
      else
        groups=("sudo" "adm" "lpadmin" "sambashare" "root")
        for group in "${groups[@]}"; do
          gpasswd -d "$user" "$group"
        done
        echo "$user has been made a standard user."
      fi

      echo "Do you want to set a custom password for $user? (yes or no)"
      read yn3
      if [ "$yn3" == "yes" ]; then
        echo "Enter the new password for $user:"
        read -s pw
        echo -e "$pw\n$pw" | passwd "$user"
        echo "$user has been given the custom password."
      else
        echo -e "Moodle!22\nMoodle!22" | passwd "$user"
        echo "$user has been given the default password 'Moodle!22'."
      fi
      passwd -x 30 -n 3 -w 7 "$user"
      usermod -L "$user"
      echo "$user's password has been configured with a maximum age of 30 days, a minimum of 3 days, and a warning of 7 days. $user's account has been locked."
    fi
  done
}

# Function to create user accounts
create_users() {
  echo "Enter user account names you want to create, separated by spaces:"
  read -a usersNew

  for userNew in "${usersNew[@]}"; do
    adduser "$userNew"
    echo "A user account for $userNew has been created."

    echo "Make $userNew an administrator? (yes or no)"
    read ynNew
    if [ "$ynNew" == "yes" ]; then
      groups=("sudo" "adm" "lpadmin" "sambashare")
      for group in "${groups[@]}"; do
        gpasswd -a "$userNew" "$group"
      done
      echo "$userNew has been made an administrator."
    else
      echo "$userNew has been made a standard user."
    fi

    passwd -x 30 -n 3 -w 7 "$userNew"
    usermod -L "$userNew"
    echo "$userNew's password has been configured with a maximum age of 30 days, a minimum of 3 days, and a warning of 7 days. $userNew's account has been locked."
  done
}

# Function to find and remove prohibited files
prohibited_files() {
  echo "Looking for prohibited files..."

  # Define a list of file extensions to search for
  extensions=("*.mov" "*.mp4" "*.mp3" "*.wav" "*.png" "*.jpg" "*.jpeg" "*.gif" "*.tar.gz" "*.php" "*backdoor*.*" "*backdoor*.php")

  for ext in "${extensions[@]}"; do
    # Use the find command to search for prohibited files
    prohibited_files=$(find / -type f -name "$ext" -path "/home/*" 2>/dev/null)

    for file in $prohibited_files; do
      echo "Prohibited file found: $file"
      read -p "Do you want to delete this file? (y/n): " ans

      case "$ans" in
        [Yy]|[Yy][Ee][Ss])
          rm -f "$file"
          echo "Deleted: $file"
          ;;
        [Nn]|[Nn][Oo])
          echo "Not deleted: $file"
          ;;
        *)
          echo "Invalid input. Skipping file: $file"
          ;;
      esac
    done
  done

  echo "Prohibited files have been checked and processed."
}


# Function to audit and remove unnecessary services
audit_services() {
  services=("apache2" "john" "hydra" "nginx" "samba" "bind9" "vsftpd" "tftpd" "x11vnc" "tightvncserver" "nfs-kernel-server" "snmp")

  for service in "${services[@]}"; do
    dpkg -l | grep -q "$service"
    if [ $? -eq 0 ]; then
      read -p "$service has been found. Do you want to remove it? (yes or no): " choice
      if [[ "$choice" == "yes" ]]; then
        apt-get autoremove -y --purge "$service" > /dev/null
      fi
    else
      echo "$service is not installed."
    fi
  done
}

# Function to reset APT repositories to default
reset_apt_repositories() {
  local sources_list="/etc/apt/sources.list"
  local backup_sources_list="/etc/apt/sources.list.bak"

  # Backup the current sources.list file
  cp "$sources_list" "$backup_sources_list"

  # Create a new default sources.list file
  cat <<EOF > "$sources_list"
deb http://deb.debian.org/debian/ bullseye main
deb-src http://deb.debian.org/debian/ bullseye main

deb http://deb.debian.org/debian-security/ bullseye-security main
deb-src http://deb.debian.org/debian-security/ bullseye-security main

deb http://deb.debian.org/debian/ bullseye-updates main
deb-src http://deb.debian.org/debian/ bullseye-updates main
EOF

  echo "APT repositories reset to default configuration."
}


antivirus_and_rootkit_check() {
    echo "Installing required packages..."
    sudo apt-get update
    sudo apt-get install -y chkrootkit rkhunter lynis clamav

    echo "Starting CHKROOTKIT scan..."
    chkrootkit -q

    echo "Starting RKHUNTER scan..."
    rkhunter --update
    rkhunter --propupd  # Run this once at install
    rkhunter -c --enable all --disable none

    echo "Starting LYNIS scan..."
    /usr/share/lynis/lynis update info
    /usr/share/lynis/lynis audit system

    echo "Starting CLAMAV scan..."
    systemctl stop clamav-freshclam
    freshclam --stdout
    systemctl start clamav-freshclam
    clamscan -r -i --stdout --exclude-dir="^/sys"
}

  
}

# Network Security
network_security() {
  echo "Installing IPtables..."
  apt-get install iptables -y > /dev/null
  clear

  echo "Adding IPtables rules..."
  # Add IPtables rules here

  echo "Enabling UFW and denying specific ports..."
  ufw enable
  ufw deny 23
  ufw deny 2049
  ufw deny 515
  ufw deny 111

  # Display active network connections and listening ports
  lsof -i -n -P
  netstat -tulpn

  echo "DONE"
}

# Function to pause and wait for user input
pause() {
  read -p "Press Enter to continue..."
}

# Main menu function
main_menu() {
  clear

  echo " 
 ██▓▄▄▄█████▓  ██████  ▄▄▄      
▓██▒▓  ██▒ ▓▒▒██    ▒ ▒████▄    
▒██▒▒ ▓██░ ▒░░ ▓██▄   ▒██  ▀█▄  
░██░░ ▓██▓ ░   ▒   ██▒░██▄▄▄▄██ 
░██░  ▒██▒ ░ ▒██████▒▒ ▓█   ▓██▒
░▓    ▒ ░░   ▒ ▒▓▒ ▒ ░ ▒▒   ▓▒█░
 ▒ ░    ░    ░ ░▒  ░ ░  ▒   ▒▒ ░
 ▒ ░  ░      ░  ░  ░    ░   ▒   
 ░                 ░        ░  ░
                                
  "
  echo "===== MAIN MENU ====="
  echo " 1) Update system."
  echo " 2) Firewall setup."
  echo " 3) Manage users."
  echo " 4) Create users."
  echo " 5) Prohibited files."
  echo " 6) Audit services."
  echo " 7) Reset Apt Repos."
  echo " 8) Anti-Virus and Rootkit check."
  echo " 9) Network Security."
  echo " 10) Exit"
  echo "======================"
  read -p "Enter your choice (1/2/3/4/5/6/7/8/9/10): " choice

  case $choice in
    1) update_system ;;
    2) setup_firewall ;;
    3) manage_users ;;
    4) create_users ;;
    5) prohibited_files ;;
    6) audit_services ;;
    7) reset_apt_repositories ;;
    8) antivirus_and_rootkit_check ;;
    9) network_security ;;
    10) echo "Exiting script"; exit 0 ;;
    *) echo "Invalid choice. Please enter a valid option." ; pause ;;
  esac
}

# Menu loop
while true; do
  main_menu
done
