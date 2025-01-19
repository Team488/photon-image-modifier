#!/bin/bash -v

# Verbose and exit on errors
set -ex

# Create pi/raspberry login
if id "$1" >/dev/null 2>&1; then
    echo 'user found'
else
    echo "creating pi user"
    useradd pi -m -b /home -s /bin/bash
    usermod -a -G sudo pi
    echo 'pi ALL=(ALL) NOPASSWD: ALL' | tee -a /etc/sudoers.d/010_pi-nopasswd >/dev/null
    chmod 0440 /etc/sudoers.d/010_pi-nopasswd
fi
echo "pi:raspberry" | chpasswd

apt-get update --quiet

before=$(df --output=used / | tail -n1)
# clean up stuff

# get rid of snaps
echo "Purging snaps"
rm -rf /var/lib/snapd/seed/snaps/*
rm -f /var/lib/snapd/seed/seed.yaml
apt-get purge --yes --quiet lxd-installer lxd-agent-loader
apt-get purge --yes --quiet snapd

# remove bluetooth daemon
apt-get purge --yes --quiet bluez

apt-get --yes --quiet autoremove

after=$(df --output=used / | tail -n1)
freed=$(( before - after ))

echo "Freed up $freed KiB"

# run Photonvision install script
chmod +x ./install.sh
./install.sh --install-nm=yes --arch=aarch64

echo "Installing additional things"
apt-get install --yes --quiet libc6 libstdc++6

# let netplan create the config during cloud-init
rm -f /etc/netplan/00-default-nm-renderer.yaml

# set NetworkManager as the renderer in cloud-init
cp -f ./OPi5_CIDATA/network-config /boot/network-config

# add customized user-data file for cloud-init
cp -f ./OPi5_CIDATA/user-data /boot/user-data

# modify photonvision.service to enable big cores
sed -i 's/# AllowedCPUs=4-7/AllowedCPUs=4-7/g' /lib/systemd/system/photonvision.service
cp -f /lib/systemd/system/photonvision.service /etc/systemd/system/photonvision.service
chmod 644 /etc/systemd/system/photonvision.service
cat /etc/systemd/system/photonvision.service

# networkd isn't being used, this causes an unnecessary delay
systemctl disable systemd-networkd-wait-online.service

# PhotonVision server is managing the network, so it doesn't need to wait for online
systemctl disable NetworkManager-wait-online.service

# the bluetooth service isn't needed and causes problems with cloud-init
# the chip has different names on different boards. Examples are:
#   OrangePi5: ap6275p-bluetooth.service
#   OrangePi5pro: ap6256s-bluetooth.service
#   OrangePi5b: ap6275p-bluetooth.service
#   OrangePi5max: ap6611s-bluetooth.service
# instead of keeping a catalog of these services, find them based on a pattern and mask them
btservices=$(systemctl list-unit-files *bluetooth.service | tail -n +2 | head -n -1 | awk '{print $1}')
for btservice in $btservices; do
    echo "Masking: $btservice"
    systemctl mask "$btservice"
done

rm -rf /var/lib/apt/lists/*
apt-get --yes --quiet clean

rm -rf /usr/share/doc
rm -rf /usr/share/locale/


# One-time setup for the Orange Pi's, needs to be connected to the internet
# make config directory
sudo mkdir -p /xbot/config

# Update and upgrade    
sudo apt-get upgrade -y
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io

# Create udev rules for the color camera (ov9782)
echo 'ATTRS{idProduct}=="6366",ATTRS{idVendor}=="0c45",SYMLINK+="color_camera",GROUP="docker", MODE="0660"' | sudo tee /etc/udev/rules.d/99-usb-camera.rules

# Restart udev to apply changes
sudo systemctl restart udev

# Add docker group (if it doesn't already exist)
getent group docker || sudo groupadd docker

# Add user to docker group
sudo usermod -aG docker pi

sudo newgrp docker

USERNAME="pv"
PASSWORD="pv"
SHELL="/bin/bash"
GROUP="pv,sudo"

sudo groupadd pv
# Create the user and add to the group
sudo useradd -m -s "$SHELL" -G "$GROUP" "$USERNAME"

SERVICE_FILE="/etc/systemd/system/photonvision.service"

# Check if the line already exists and add or replace it
if grep -q "^User=" "$SERVICE_FILE"; then
    # Replace the existing User line
    sudo sed -i "s/^User=.*/User=pv/" "$SERVICE_FILE"
else
    # Add the User line under the [Service] section
    sudo sed -i "/^\[Service\]/a User=pv" "$SERVICE_FILE"
fi

# Reload systemd to apply changes
sudo systemctl daemon-reload
sudo systemctl restart photonvision

sudo chown -R pv:pv /opt/photonvision


if [ -e "/root/.wpilib" ]; then
  sudo mv /root/.wpilib /home/pv/
  sudo chown -R pv:pv /home/pv/.wpilib 
else
  echo "File does not exist, skipping move."
fi


