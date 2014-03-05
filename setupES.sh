#!/bin/bash

export ES_VERSION=1.0.1
export ES_AZURE_VERSION=2.0.0
export ES_MARVEL_VERSION=1.0.2

echo Installing VIM Config
rm ~/.vimrc
ln -s ~/ESInstall/ConfigFiles/vimrc ~/.vimrc

echo Updating system to latest packages
sudo apt-get update
sudo apt-get dist-upgrade -y

echo Installing Java
sudo apt-get install openjdk-7-jre-headless -y

echo Installing ElasticSearch
curl -s https://download.elasticsearch.org/elasticsearch/elasticsearch/elasticsearch-$ES_VERSION.deb -o elasticsearch-$ES_VERSION.deb
sudo dpkg -i elasticsearch-$ES_VERSION.deb

echo Installing ElasticSearch plugins
sudo /usr/share/elasticsearch/bin/plugin -install elasticsearch/elasticsearch-cloud-azure/$ES_AZURE_VERSION
sudo /usr/share/elasticsearch/bin/plugin -install elasticsearch/marvel/$ES_MARVEL_VERSION
