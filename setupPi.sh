# One-time setup for the Orange Pi's, needs to be connected to the internet
# make config directory
sudo mkdir -p /xbot/config

# Update and upgrade    
sudo apt-get upgrade -y
sudo apt update
sudo apt install -y ca-certificates curl gnupg
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io

# Create udev rules for the color camera (ov9782)
echo 'ATTRS{idProduct}=="6366",ATTRS{idVendor}=="0c45",SYMLINK+="color_camera",GROUP="docker", MODE="0660"' | sudo tee /etc/udev/rules.d/99-usb-camera.rules

# Restart udev to apply changes
sudo systemctl restart udev

# Add docker group (if it doesn't already exist)
getent group docker || sudo groupadd docker

# Add user to docker group
sudo usermod -aG docker $USER

sudo newgrp docker

USERNAME="pv"
PASSWORD="pv"
SHELL="/bin/bash"
GROUP="pv,sudo"

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
