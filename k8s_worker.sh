#!/bin/bash
echo "Disabling swap...."
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
sudo tee /etc/modules-load.d/containerd.conf <<EOF
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter
sudo tee /etc/sysctl.d/kubernetes.conf <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
sudo sysctl --system
echo "Installing containerd..."
sudo apt install -y curl gnupg2 software-properties-common apt-transport-https ca-certificates
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmour -o /etc/apt/trusted.gpg.d/docker.gpg
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" -y
sudo apt update
sudo apt install -y containerd.io
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null 2>&1
sudo sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd
echo "Removing existing k8s..."
sudo swapoff -a 
sudo kubeadm reset
sudo rm -rf /var/lib/cni/
sudo systemctl daemon-reload
sudo iptables -F && sudo iptables -t nat -F && sudo iptables -t mangle -F && sudo iptables -X
sudo apt-mark unhold kubelet kubeadm kubectl
sudo apt-get purge kubeadm kubectl kubelet kubernetes-cni -y
sudo rm -rf /etc/kubernetes
sudo rm -rf $HOME/.kube/config
sudo rm -rf /var/lib/etcd
sudo rm -rf /var/lib/docker
sudo rm -rf /opt/containerd
sudo rm -rf /opt/cni/bin
sudo apt autoremove -y
echo "Installing k8s..."
sudo curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
sudo apt-add-repository "deb http://apt.kubernetes.io/ kubernetes-xenial main" -y
sudo apt-get update
sudo apt-get install -y kubelet=1.25.0-00 kubeadm=1.25.0-00 kubectl=1.25.0-00
sudo apt-mark hold kubelet kubeadm kubectl
echo "Installing firewalld..."
sudo apt-get install firewalld -y
sudo sleep 10
echo "Configure on worker..."
# sudo firewall-cmd --zone=public --permanent --add-port={10250,30000-32767}/tcp
# sudo firewall-cmd --reload
sudo systemctl stop firewalld.service
echo "Kubernetes Installation finished..."

# When Unauthorized occurs during Kubernetes worker-node join
# sudo apt-get purge containerd.io docker-ce
# rm -rf /var/lib/containerd
# [reboot]
# sudo apt-get install containerd.io docker-ce
