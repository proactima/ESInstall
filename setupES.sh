#!/bin/bash

ES_VERSION=1.0.1
ES_AZURE_VERSION=2.0.0
ES_MARVEL_VERSION=1.0.2
ES_KIBANA_VERSION=3.0.0milestone5

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
    nodejs updown.js config down uxrisk-keystore.pkcs12 >> /tmp/downloaded.log 2>&1
    nodejs updown.js config down elasticsearch.yml >> /tmp/downloader.log 2>&1
    nodejs updown.js config down logging.yml >> /tmp/downloader.log 2>&1
    nodejs updown.js config down elasticsearch >> /tmp/downloader.log 2>&1
}

function ConfigureES {
    read -p "Node name? " nodeName
    sed -i "s/NODENAME/$nodeName/i" elasticsearch.yml
    sudo cp ~/elasticsearch.yml /etc/elasticsearch/elasticsearch.yml
    sudo cp ~/logging.yml /etc/elasticsearch/logging.yml
    sudo cp ~/elasticsearch /etc/default/elasticsearch
}

function DoStagingSpecific {
    if ask "Is this staging? " N; then
        echo Staging detected
        echo Installing Nginx...
        sudo apt-get install nginx -y
        
        echo Installing Kibana
        KIBANA_DIRECTORY=kibana-$ES_KIBANA_VERSION
        KIBANA_FILENAME=$KIBANA_DIRECTORY.tar.gz
        wget --no-check-certificate https://download.elasticsearch.org/kibana/kibana/$KIBANA_FILENAME -O ~/$KIBANA_FILENAME > /tmp/wgetKibana 2>&1
        mkdir -p /tmp/kibana
        tar zxvf ~/$KIBANA_FILENAME -C /tmp/kibana > /tmp/tarKibana 2>&1
        sudo rm -rf /usr/share/nginx/html/*
        sudo cp -R /tmp/kibana/$KIBANA_DIRECTORY/* /usr/share/nginx/html/
        rm -rf /tmp/kibana
        
        echo Configuring Nginx
        nodejs updown.js config down nginx-staging >> /tmp/downloader.log 2>&1
        sudo cp ~/nginx-staging /etc/nginx/sites-available/default > /tmp/nginx.log 2>&1
        
        sudo service nginx start
    fi
}

function Reboot {
    echo Rebooting...
    sudo reboot
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
DoStagingSpecific
Reboot
