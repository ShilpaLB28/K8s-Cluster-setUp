#!/bin/bash
sudo apt update 

sudo apt install -y apt-transport-https ca-certificates curl gpg

#Disable swap
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

#Enable required kernel modules and settings
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

sudo sysctl --system


#Install Container Runtime (Containerd)
sudo apt install -y containerd

#Configure containerd with systemd as cgroup driver
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd



#Install Kubernetes Tools
sudo curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list


#Install kubeadm, kubelet, kubectl
sudo apt update
sudo apt install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl


sudo systemctl enable --now kubelet

sudo apt update
sudo apt install -y conntrack

if [ "$1" == "master" ]; then
sudo kubeadm init

echo "---------------------------"
echo "save the above kubeadm join token"
echo "---------------------------"

#When complete, you’ll see a kubeadm join ... command — copy that for joining workers.

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config


kubectl get nodes
#Should show the control plane as NotReady until networking is installed.


#Install Pod Network (e.g., Calico)
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.2/manifests/calico.yaml


#Wait a few minutes, then:

kubectl get nodes
#All should become Ready.


kubectl get pods -A
#all pods should be running

fi

if [ "$1" == "worker" ]; then

#On each worker node, run the command shown at the end of kubeadm init, e.g.:
#below command should be picked from ur kubeadm init command output

echo " Run the kubeadm join <<token>> command which you get from master node. "
fi