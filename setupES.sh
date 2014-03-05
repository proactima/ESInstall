#!/bin/bash

export ES_VERSION=1.0.1
export ES_AZURE_VERSION=2.0.0
export ES_MARVEL_VERSION=1.0.2

function SetupVim {
    echo Installing VIM Config
    wget --no-check-certificate https://raw.github.com/proactima/ESInstall/master/ConfigFiles/vimrc
    mv ~/vimrc ~/.vimrc
}

function UpdateSystem {
    echo Updating system to latest packages
    sudo apt-get update
    sudo apt-get dist-upgrade -y
}

function InstallJava {
    echo Installing Java
    sudo apt-get install openjdk-7-jre-headless -y
}

function InstallES {
    echo Installing ElasticSearch
    curl -s https://download.elasticsearch.org/elasticsearch/elasticsearch/elasticsearch-$ES_VERSION.deb -o elasticsearch-$ES_VERSION.deb
    sudo dpkg -i elasticsearch-$ES_VERSION.deb

    echo Installing ElasticSearch plugins
    sudo /usr/share/elasticsearch/bin/plugin -install elasticsearch/elasticsearch-cloud-azure/$ES_AZURE_VERSION
    sudo /usr/share/elasticsearch/bin/plugin -install elasticsearch/marvel/$ES_MARVEL_VERSION
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

#SetupVim
#UpdateSystem
#InstallJava
#InstallES
AskToConfigureDataDisk
