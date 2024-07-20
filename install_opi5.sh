
# Create pi/raspberry login
if id "$1" >/dev/null 2>&1; then
    echo 'user found'
else
    echo "creating pi user"
    useradd pi -b /home -s /usr/bin/bash
    usermod -a -G sudo pi
    mkdir /home/pi
    chown -R pi /home/pi
    # Don't ask for password on sudo for pi user, as on Raspberry Pi
    echo 'pi ALL=(ALL) NOPASSWD: ALL' | tee -a /etc/sudoers.d/010_pi-nopasswd >/dev/null
    chmod 0440 /etc/sudoers.d/010_pi-nopasswd
fi
echo "pi:raspberry" | chpasswd

apt-get update
wget https://git.io/JJrEP -O install.sh
chmod +x install.sh

sed -i 's/# AllowedCPUs=4-7/AllowedCPUs=4-7/g' install.sh

./install.sh -m -q
rm install.sh


# Remove extra packages 
echo "Purging extra things"
# apt-get remove -y gdb gcc g++ linux-headers* libgcc*-dev
# apt-get remove -y snapd
apt-get autoremove -y


echo "Installing additional things"
sudo apt-get update
apt-get install -y network-manager net-tools libatomic1

apt-get install -y libc6 libstdc++6

# Fallback to a link-local IP if not connected to a network with DHCP
cat > /etc/NetworkManager/system-connections/fallback-link-local.nmconnection <<EOF
[connection]
id=fallback-link-local
uuid=3dbf658d-cf93-4a9c-a18d-8ccb6647b0d8
type=ethernet
autoconnect=true
autoconnect-priority=-999

[ethernet]

[match]
interface-name=en*

[ipv4]
method=link-local

[ipv6]
method=disabled

[proxy]
EOF
chmod 0600 /etc/NetworkManager/system-connections/fallback-link-local.nmconnection

if [ $(cat /etc/lsb-release | grep -c "24.04") -gt 0 ]; then
    # add jammy to apt sources 
    echo "Adding jammy to list of apt sources"
    add-apt-repository -y -S 'deb http://ports.ubuntu.com/ubuntu-ports jammy main universe'
fi

apt-get update

# mrcal stuff
apt-get install -y libcholmod3 liblapack3 libsuitesparseconfig5


rm -rf /var/lib/apt/lists/*
apt-get clean

rm -rf /usr/share/doc
rm -rf /usr/share/locale/
