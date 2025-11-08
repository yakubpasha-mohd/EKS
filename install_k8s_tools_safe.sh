#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

echo "=========================================="
echo " Installing AWS CLI v2, eksctl, and kubectl "
echo "=========================================="

# Detect OS type
if [ -f /etc/os-release ]; then
  . /etc/os-release
  OS=$ID
else
  echo "Cannot detect OS. Exiting."
  exit 1
fi

echo "Detected OS: $OS"

# Helper: install packages without forcing curl on Amazon Linux
install_packages() {
  packages=("$@")
  if [[ "$OS" == "amzn" ]] || [[ "$OS" == "rhel" ]] || [[ "$OS" == "centos" ]]; then
    # For Amazon Linux 2023 avoid trying to install 'curl' if a curl binary already exists
    to_install=()
    for p in "${packages[@]}"; do
      if [[ "$p" == "curl" ]]; then
        if command -v curl >/dev/null 2>&1; then
          echo "curl already present — skipping package install for curl"
          continue
        fi
      fi
      to_install+=("$p")
    done

    if [ "${#to_install[@]}" -gt 0 ]; then
      sudo yum install -y "${to_install[@]}"
    else
      echo "No packages to install for yum."
    fi

  elif [[ "$OS" == "ubuntu" ]] || [[ "$OS" == "debian" ]]; then
    sudo apt-get update -y
    sudo apt-get install -y "${packages[@]}"
  else
    echo "Unsupported OS. Please use Amazon Linux, RHEL, CentOS, Ubuntu or Debian."
    exit 1
  fi
}

# Ensure unzip and tar (do NOT force-install curl if present)
echo "Installing unzip and tar (and curl only if missing)..."
install_packages unzip tar curl

# Re-check curl presence (if missing, provide guidance and attempt safe install)
if ! command -v curl >/dev/null 2>&1; then
  echo "curl not found. Attempting to install curl (safe attempt)..."
  if [[ "$OS" == "amzn" ]] || [[ "$OS" == "rhel" ]] || [[ "$OS" == "centos" ]]; then
    # Try yum install curl; if conflicts occur, suggest using curl-minimal or update system
    if sudo yum install -y curl; then
      echo "curl installed successfully."
    else
      echo "Failed to install 'curl' via yum. Trying curl-minimal..."
      sudo yum install -y curl-minimal || {
        echo "Unable to install curl or curl-minimal automatically. Run 'sudo yum update -y' and try again, or keep curl-minimal if present."
      }
    fi
  else
    sudo apt-get install -y curl
  fi
fi

#--------------------------------------------
# 2. Install AWS CLI v2
#--------------------------------------------
echo "Installing AWS CLI v2..."
cd /tmp || exit 1
curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
sudo ./aws/install -i /usr/local/aws-cli -b /usr/local/bin || {
  echo "aws install returned non-zero exit code. Checking aws --version..."
}
if command -v aws >/dev/null 2>&1; then
  aws --version
else
  echo "AWS CLI install failed or aws not in PATH. You may need to add /usr/local/bin to PATH."
fi

#--------------------------------------------
# 3. Install eksctl
#--------------------------------------------
echo "Installing eksctl..."
cd /tmp || exit 1
curl -sLO "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz"
sudo tar -xzf eksctl_$(uname -s)_amd64.tar.gz -C /usr/local/bin
sudo chmod +x /usr/local/bin/eksctl
if command -v eksctl >/dev/null 2>&1; then
  eksctl version
else
  echo "eksctl not found after install. Check /usr/local/bin permissions."
fi

#--------------------------------------------
# 4. Install kubectl (latest stable)
#--------------------------------------------
echo "Installing kubectl..."
cd /tmp || exit 1
K8S_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
curl -LO "https://dl.k8s.io/release/${K8S_VERSION}/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
kubectl version --client

#--------------------------------------------
# 5. Final notes
#--------------------------------------------
echo "------------------------------------------"
echo " To configure AWS CLI, run: aws configure "
echo "------------------------------------------"

echo "Installation completed (or attempted). Summary:"
command -v aws >/dev/null 2>&1 && aws --version || echo "aws: not installed"
command -v eksctl >/dev/null 2>&1 && eksctl version || echo "eksctl: not installed"
command -v kubectl >/dev/null 2>&1 && kubectl version --client || echo "kubectl: not installed"
