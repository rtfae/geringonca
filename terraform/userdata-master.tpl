#!/bin/bash
sudo apt-get update -y
sudo apt-get upgrade -y
sudo apt-get install python3-pip apt-transport-https curl -y
sudo pip3 install awscli
echo "AWS_DEFAULT_REGION=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | grep region | awk -F\" '{print $4}')" | sudo tee -a /etc/environment
echo "HOSTEDZONE_NAME=${domain}" | sudo tee -a /etc/environment
echo "INTERNAL_IP=$(curl -s http://169.254.169.254/1.0/meta-data/local-ipv4)" | sudo tee -a /etc/environment

sudo curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
sudo echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" >/etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y docker.io kubeadm

sudo systemctl enable docker.service

# Run kubeadm
sudo kubeadm init \
    --token "${token}" \
    --token-ttl 15m \
    --apiserver-cert-extra-sans "kube.${domain}" \
    --node-name master

#Prepare kubeconfig file for download to local machine
sudo cp /etc/kubernetes/admin.conf /home/ubuntu
sudo chown ubuntu:ubuntu /home/ubuntu/admin.conf
sudo kubectl --kubeconfig /home/ubuntu/admin.conf config set-cluster ${cluser_name} --server https://kube.${domain}:6443

# Indicate completion of bootstrapping on this node
touch /home/ubuntu/done
