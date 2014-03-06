#!/bin/bash

export ES_VERSION=1.0.1
export ES_AZURE_VERSION=2.0.0
export ES_MARVEL_VERSION=1.0.2

function SetupVim {
    echo Installing VIM Config
    wget --no-check-certificate https://raw.github.com/proactima/ESInstall/master/ConfigFiles/vimrc -O vimrc > /tmp/aptVimrc 2>&1
    mv ~/vimrc ~/.vimrc
}

function UpdateSystem {
    echo Updating system to latest packages
    sudo apt-get update  > /tmp/aptUpdate 2>&1
    sudo apt-get dist-upgrade -y > /tmp/aptDistUpgrade.log 2>&1
    sudo apt-get install -y htop
}

function InstallNode {
    echo Installing Node.js
    sudo apt-get install nodejs npm -y > /tmp/aptNode.log 2>&1

    echo Installing Windows Azure Node.js module...
    npm install azure > /tmp/nodeInstall.log 2>&1

    echo Installing Azure Storage Node.js wrapper module
    wget --no-check-certificate https://raw.github.com/jeffwilcox/waz-updown/master/updown.js -O updown.js > /tmp/updownInstall.log 2>&1
}

function InstallJava {
    echo Installing Java
    sudo apt-get install openjdk-7-jre-headless -y > /tmp/aptJava 2>&1
}

function InstallES {
    echo Installing ElasticSearch
    curl -s https://download.elasticsearch.org/elasticsearch/elasticsearch/elasticsearch-$ES_VERSION.deb -o elasticsearch-$ES_VERSION.deb > /tmp/aptWgetES 2>&1
    sudo dpkg -i elasticsearch-$ES_VERSION.deb --force-all > /tmp/aptESInstall 2>&1

    echo Installing ElasticSearch plugins
    sudo /usr/share/elasticsearch/bin/plugin -install elasticsearch/elasticsearch-cloud-azure/$ES_AZURE_VERSION > /tmp/aptPluginAzure 2>&1
    sudo /usr/share/elasticsearch/bin/plugin -install elasticsearch/marvel/$ES_MARVEL_VERSION > /tmp/aptPluginMarvel 2>&1
}

function AskToConfigureDataDisk {
    if ask "Have you attaced a data disk? " Y; then
        if [ -e /dev/sdc1 ]; then
            echo "Partition already exists, skipping"
        else
            ConfigureDataDisk
        fi
    fi
}

function ConfigureDataDisk {
    esDataPath=/mnt/es/data

    echo Checking for attached Windows Azure data disk
    while [ ! -e /dev/sdc ]; do echo waiting for /dev/sdc empty disk to attach; sleep 20; done

    echo Partitioning...
    sudo fdisk /dev/sdc <<ENDPARTITION > /tmp/fdisk.log 2>&1
n
p
1


w
ENDPARTITION

    echo Formatting with EXT4
    sudo mkfs.ext4 /dev/sdc1 > /tmp/format.log 2>&1

    echo Preparing permanent data disk mount point at /mnt/data
    sudo mkdir /mnt/es
    echo '/dev/sdc1 /mnt/es ext4 defaults,auto,noatime,nodiratime,noexec 0 0' | sudo tee -a /etc/fstab

    echo Mounting the new disk...
    sudo mount /mnt/es
    sudo e2label /dev/sdc1 /mnt/es
    sudo mkdir -p /mnt/es/data
    sudo chown elasticsearch /mnt/es/data
}

function ConfigureAzure {
    if [ -z "$AZURE_STORAGE_ACCOUNT" ]; then
        read -p "Windows Azure storage account name? " storageAccount
        export AZURE_STORAGE_ACCOUNT=$storageAccount
        echo
    fi

    if [ -z "$AZURE_STORAGE_ACCESS_KEY" ]; then
        read -s -p "Account access key? " storageKey
        export AZURE_STORAGE_ACCESS_KEY=$storageKey
        echo
    fi
}

function DownloadFiles {
    nodejs updown.js config down uxrisk-staging-keystore.pkcs12 > /tmp/downloaded.log 2>&1
    nodejs updown.js config down elasticsearch-staging.yml > /tmp/downloader.log 2>&1
}

function ConfigureES {
    read -p "Node name? " nodeName
    sed -i "s/NODENAME/$nodeName/i" elasticsearch-staging.yml
    sudo cp ~/elasticsearch-staging.yml /etc/elasticsearch/elasticsearch.yml
}

# Awesome ask function by @davejamesmiller https://gist.github.com/davejamesmiller/1965569
function ask {
    while true; do

    if [ "${2:-}" = "Y" ]; then
        prompt="Y/n"
        default=Y
    elif [ "${2:-}" = "N" ]; then
        prompt="y/N"
        default=N
    else
        prompt="y/n"
        default=
    fi

    # Ask the question
    read -p "$1 [$prompt] " REPLY

    # Default?
    if [ -z "$REPLY" ]; then
        REPLY=$default
    fi

    # Check if the reply is valid
    case "$REPLY" in
        Y*|y*) return 0 ;;
        N*|n*) return 1 ;;
    esac

    done
}

cd ~

SetupVim
UpdateSystem
InstallJava
InstallNode
InstallES
AskToConfigureDataDisk
ConfigureAzure
DownloadFiles
ConfigureES
