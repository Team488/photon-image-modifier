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


# Create the user and add to the group
if ! id "pv" &>/dev/null; then
    sudo useradd pv -m -s "$SHELL"
else
    echo "User pv already exists, skipping user creation."
fi

sudo usermod -aG sudo pv




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

if [ -d "/opt/photonvision" ]; then
  sudo chown -R pv:pv /opt/photonvision
else
  echo "/opt/photonvision directory not found."
fi


if [ ! -d "/home/pv" ]; then
    sudo mkdir -p /home/pv
fi



if [ -e "/root/.wpilib" ]; then
  sudo mv /root/.wpilib /home/pv/
  sudo chown -R pv:pv /home/pv/.wpilib 
else
  echo "File does not exist, skipping move."
fi

