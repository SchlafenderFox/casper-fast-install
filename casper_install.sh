#!/bin/bash

CASPER_VERSION=1_0_0

CASPER_NETWORK=casper-test

sudo apt-get update
sudo apt install git

sudo apt install dnsutils -y

sudo apt install jq -y

echo "deb https://repo.casperlabs.io/releases" bionic main | sudo tee -a /etc/apt/sources.list.d/casper.list
curl -O https://repo.casperlabs.io/casper-repo-pubkey.asc
sudo apt-key add casper-repo-pubkey.asc
sudo apt update

sudo apt install casper-node-launcher -y
sudo apt install casper-client -y

cd ~
sudo apt purge --auto-remove cmake
wget -O - https://apt.kitware.com/keys/kitware-archive-latest.asc 2>/dev/null | gpg --dearmor - | sudo tee /etc/apt/trusted.gpg.d/kitware.gpg >/dev/null
sudo apt-add-repository 'deb https://apt.kitware.com/ubuntu/ focal main'   
sudo apt update
sudo apt install cmake -y

curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

sudo apt install libssl-dev -y
sudo apt install pkg-config -y
sudo apt install build-essential -y

BRANCH="1.0.20" \
    && git clone --branch ${BRANCH} https://github.com/WebAssembly/wabt.git "wabt-${BRANCH}" \
    && cd "wabt-${BRANCH}" \
    && git submodule update --init \
    && cd - \
    && cmake -S "wabt-${BRANCH}" -B "wabt-${BRANCH}/build" \
    && cmake --build "wabt-${BRANCH}/build" --parallel 8 \
    && sudo cmake --install "wabt-${BRANCH}/build" --prefix /usr --strip -v \
    && rm -rf "wabt-${BRANCH}"

cd ~

git clone git://github.com/CasperLabs/casper-node.git
cd casper-node/

git checkout release-1.3.2

make setup-rs
make build-client-contracts -j

cd /etc/casper/validator_keys

sudo -u casper casper-client keygen .

sudo -u casper /etc/casper/pull_casper_node_version.sh $CASPER_NETWORK.conf $CASPER_VERSION
sudo -u casper /etc/casper/config_from_example.sh $CASPER_VERSION

KNOWN_ADDRESSES=$(sudo -u casper cat /etc/casper/$CASPER_VERSION/config.toml | grep known_addresses)
KNOWN_VALIDATOR_IPS=$(grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' <<< "$KNOWN_ADDRESSES")
IFS=' ' read -r KNOWN_VALIDATOR_IP _REST <<< "$KNOWN_VALIDATOR_IPS"

echo $KNOWN_VALIDATOR_IP

# Get trusted_hash into config.toml
TRUSTED_HASH=$(casper-client get-block --node-address http://$KNOWN_VALIDATOR_IP:7777 -b 20 | jq -r .result.block.hash | tr -d '\n')
if [ "$TRUSTED_HASH" != "null" ]; then sudo -u casper sed -i "/trusted_hash =/c\trusted_hash = '$TRUSTED_HASH'" /etc/casper/$CASPER_VERSION/config.toml; fi

sudo -u casper /etc/casper/pull_casper_node_version.sh casper-test.conf 1_1_0
sudo -u casper /etc/casper/config_from_example.sh 1_1_0

sudo -u casper /etc/casper/pull_casper_node_version.sh casper-test.conf 1_1_2
sudo -u casper /etc/casper/config_from_example.sh 1_1_2

sudo -u casper /etc/casper/pull_casper_node_version.sh casper-test.conf 1_2_0
sudo -u casper /etc/casper/config_from_example.sh 1_2_0

sudo -u casper /etc/casper/pull_casper_node_version.sh casper-test.conf 1_2_1
sudo -u casper /etc/casper/config_from_example.sh 1_2_1

sudo -u casper /etc/casper/pull_casper_node_version.sh casper-test.conf 1_3_1
sudo -u casper /etc/casper/config_from_example.sh 1_3_1

sudo -u casper /etc/casper/pull_casper_node_version.sh casper-test.conf 1_3_2
sudo -u casper /etc/casper/config_from_example.sh 1_3_2

sudo -u casper /etc/casper/pull_casper_node_version.sh casper-test.conf 1_3_4
sudo -u casper /etc/casper/config_from_example.sh 1_3_4

sudo -u casper /etc/casper/pull_casper_node_version.sh casper-test.conf 1_4_1
sudo -u casper /etc/casper/config_from_example.sh 1_4_1

sudo -u casper /etc/casper/pull_casper_node_version.sh casper-test.conf 1_4_2
sudo -u casper /etc/casper/config_from_example.sh 1_4_2

sudo -u casper /etc/casper/pull_casper_node_version.sh casper-test.conf 1_4_3
sudo -u casper /etc/casper/config_from_example.sh 1_4_3

sudo logrotate -f /etc/logrotate.d/casper-node
sudo systemctl start casper-node-launcher; sleep 2
systemctl status casper-node-launcher
