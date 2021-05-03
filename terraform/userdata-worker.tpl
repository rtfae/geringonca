#!/bin/bash
sudo apt-get update -y
sudo apt-get upgrade -y
sudo apt-get install python3-pip apt-transport-https curl -y
sudo pip3 install awscli
RANDOM_NUMBER=$(shuf -i 10-250 -n 1)
echo "AWS_DEFAULT_REGION=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | grep region | awk -F\" '{print $4}')" | sudo tee -a /etc/environment
echo "HOSTEDZONE_NAME=${domain}" | sudo tee -a /etc/environment
echo "INTERNAL_IP=$(curl -s http://169.254.169.254/1.0/meta-data/local-ipv4)" | sudo tee -a /etc/environment

sudo curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
sudo echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" >/etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y docker.io kubeadm

sudo systemctl enable docker.service

# Run kubeadm
sudo kubeadm join https://kube.${domain}:6443 \
    --token "${token}" \
    --discovery-token-unsafe-skip-ca-verification \
    --node-name worker-$(curl -s http://169.254.169.254/1.0/meta-data/local-ipv4)

# Indicate completion of bootstrapping on this node
touch /home/ubuntu/done