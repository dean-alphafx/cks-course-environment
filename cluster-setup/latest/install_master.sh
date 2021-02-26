#!/bin/sh

# Source: http://kubernetes.io/docs/getting-started-guides/kubeadm/

### setup terminal
apt-get install -y bash-completion binutils
echo 'colorscheme ron' >> ~/.vimrc
echo 'set tabstop=2' >> ~/.vimrc
echo 'set shiftwidth=2' >> ~/.vimrc
echo 'set expandtab' >> ~/.vimrc
echo 'source <(kubectl completion bash)' >> ~/.bashrc
echo 'alias k=kubectl' >> ~/.bashrc
echo 'alias c=clear' >> ~/.bashrc
echo 'complete -F __start_kubectl k' >> ~/.bashrc
sed -i '1s/^/force_color_prompt=yes\n/' ~/.bashrc


### install k8s and containerd
apt-get remove -y containerd apt-transport-https docker.io kubelet kubeadm kubectl kubernetes-cni
apt-get autoremove -y
apt-get install -y etcd-client vim build-essential

systemctl daemon-reload
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF > /etc/apt/sources.list.d/kubernetes.list
deb http://apt.kubernetes.io/ kubernetes-xenial main
EOF
KUBE_VERSION=1.20.2
apt-get update
apt-get install -y containerd apt-transport-https kubelet=${KUBE_VERSION}-00 kubeadm=${KUBE_VERSION}-00 kubectl=${KUBE_VERSION}-00 kubernetes-cni=0.8.7-00
mkdir /etc/containerd
containerd config default > /etc/containerd/config.toml
systemctl restart containerd
systemctl enable containerd >/dev/null 2>&1

### Enable and Load Kernel modules
cat >> /etc/modules-load.d/containerd.conf<<EOF
overlay
br_netfilter
EOF
modprobe overlay
modprobe br_netfilter

cat >>/etc/sysctl.d/kubernetes.conf<<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
EOF
sysctl --system >/dev/null 2>&1

systemctl enable kubelet && systemctl start kubelet

curl -s https://falco.org/repo/falcosecurity-3672BA8F.asc | apt-key add -
echo "deb https://dl.bintray.com/falcosecurity/deb stable main" | tee -a /etc/apt/sources.list.d/falcosecurity.list
apt-get update -y
apt-get -y install linux-headers-$(uname -r)
apt-get install -y falco
systemctl start falco

### init k8s
rm /root/.kube/config
kubeadm reset -f
kubeadm init --kubernetes-version=${KUBE_VERSION} --ignore-preflight-errors=NumCPU --skip-token-print

mkdir -p ~/.kube
sudo cp -i /etc/kubernetes/admin.conf ~/.kube/config

kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"

echo
echo "### COMMAND TO ADD A WORKER NODE ###"
kubeadm token create --print-join-command --ttl 0
