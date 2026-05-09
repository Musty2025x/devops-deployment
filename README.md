# End-to-End DevOps Deployment — Docker + Terraform + CI/CD + Custom Domain

## Real-World Scenario

> You're working at **Techie Hub**. The company already has a PHP website (not containerized). They want it containerized, deployed to Azure VM, auto-deployed on code push, and accessible via a custom domain.

---

## Architecture

```
Developer (VS Code)
       │
       │  git push origin main
       ▼
GitHub Repository (devops-deployment)
       │
       │  Triggers GitHub Actions workflow
       ▼
GitHub Actions (deploy.yml)
       │
       │  appleboy/ssh-action → SSH into Azure VM
       ▼
Azure VM — Ubuntu 22.04 (php-vm)
Provisioned by Terraform
       │
       ├── Docker
       │     └── php-app container (PHP 8.2 + Apache)
       │           └── port 3000:80
       │
       └── Nginx (reverse proxy)
             └── port 80/443 → localhost:3000
       │
       ▼
Public IP (Static) → DNS A Record
       │
       ▼
https://app.yourtechiehub.com.ng
(Let's Encrypt SSL via Certbot)
```

> ![alt text](asset/Architecture_diagram.png)
---

## Tech Stack

| Layer | Technology |
|---|---|
| Application | PHP 8.2 + Apache (Dockerized) |
| Containerization | Docker |
| Infrastructure (IaC) | Terraform — Azure Provider |
| Cloud Hosting | Azure VM — Ubuntu 22.04 — Standard_B1s |
| CI/CD | GitHub Actions + `appleboy/ssh-action` |
| Reverse Proxy | Nginx |
| SSL | Let's Encrypt via Certbot |
| Domain | Any registrar (Qservers, Namecheap, GoDaddy) |

---

## Prerequisites

- Azure account with active subscription
- GitHub account
- Installed locally:
  - Terraform
  - Docker Desktop
  - Azure CLI (`az`)
  - Git

---

## Project Structure

```
devops-deployment/
│
├── charitize/                  # PHP application + Dockerfile
│   ├── index.php
│   ├── Dockerfile
│   └── ...                     # CSS, JS, images, other PHP files
│
├── terraform/                  # Infrastructure as Code
│   ├── main.tf
│   └── outputs.tf
│
├── .github/
│   └── workflows/
│       └── deploy.yml          # CI/CD pipeline
│
└── .gitignore
```

---

## Phase 1 — Prepare the PHP Application

### Step 1 — Download the PHP app

Download the existing PHP application:
[Google Drive — PHP App](https://drive.google.com/drive/folders/1V3qwGMDSoR7hR24_mIpnNLe-3Ch3CQqx?usp=sharing)

Unzip and extract to your working directory.

### Step 2 — Create the Dockerfile

Create a `Dockerfile` inside the `charitize/` folder:

```dockerfile
# Use official PHP image with Apache
FROM php:8.2-apache

# Set working directory inside container
WORKDIR /var/www/html

# Copy application files into container
COPY . /var/www/html

# Expose port 80
EXPOSE 80

# Apache runs automatically in this base image
```

### Step 3 — Test locally

Open Docker Desktop to ensure the Docker daemon is running, then:

```bash
cd charitize
docker build -t php-app .
docker run -d -p 8080:80 php-app
```

## screenshot of Docker build and run commands executed successfully in local terminal

> ![alt text](asset/Screenshot-2026-05-08_081808.png)
> ![alt text](asset/Screenshot-2026-05-08_081837.png)

Open in browser: **http://localhost:8080**

The Charitize PHP app should render correctly.

## screenshot of the app running locally on http://localhost:8080

> ![alt text](asset/Screenshot-2026-05-08_081857.png)


---

## Phase 2 — Push to GitHub

### Step 4 — Create `.gitignore`

Create a `.gitignore` file in the project root to exclude Terraform cache and sensitive files:

```
# Terraform
.terraform/
*.tfstate
*.tfstate.*
crash.log

# Sensitive files
*.pem
*.key

# OS files
.DS_Store
Thumbs.db
```

### Step 5 — Initialise Git and push

```bash
# Make sure you are inside: devops-deployment/
git init
git add .
git commit -m "Initial commit - PHP app + Terraform + CI/CD"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/devops-deployment.git
git push -u origin main
```

---

## Phase 3 — Provision Infrastructure with Terraform

### Step 6 — Create `terraform/main.tf`

```hcl
provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "rg-php-devops"
  location = "East US"
}

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-php"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "subnet-php"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_network_security_group" "nsg" {
  name                = "nsg-php"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTP"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTPS"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowDocker"
    priority                   = 1004
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3000"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_public_ip" "pip" {
  name                = "php-public-ip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
}

resource "azurerm_network_interface" "nic" {
  name                = "php-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip.id
  }
}

resource "azurerm_network_interface_security_group_association" "assoc" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_linux_virtual_machine" "vm" {
  name                = "php-vm"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_B1s"
  admin_username      = "azureuser"

  network_interface_ids = [azurerm_network_interface.nic.id]

  admin_ssh_key {
    username   = "azureuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}
```

### Step 7 — Create `terraform/outputs.tf`

```hcl
output "vm_public_ip" {
  description = "The public IP address of the PHP VM"
  value       = azurerm_public_ip.pip.ip_address
}

output "vm_username" {
  description = "The admin username for SSH access"
  value       = azurerm_linux_virtual_machine.vm.admin_username
}

output "ssh_connection_command" {
  description = "Ready-to-use SSH command to connect to the VM"
  value       = "ssh -i ~/.ssh/id_rsa ${azurerm_linux_virtual_machine.vm.admin_username}@${azurerm_public_ip.pip.ip_address}"
}

output "vm_name" {
  description = "The name of the virtual machine"
  value       = azurerm_linux_virtual_machine.vm.name
}

output "resource_group_name" {
  description = "The resource group containing all resources"
  value       = azurerm_resource_group.rg.name
}
```

### Step 8 — Deploy infrastructure

```bash
cd terraform
az login
terraform init
terraform plan
terraform apply
```

Note the `vm_public_ip` from the output — you will need it for GitHub Secrets and DNS.

> **Note:** If `Standard_B1s` is unavailable in `West Europe`, change the location to `East US` in `main.tf`. Since all resources reference `azurerm_resource_group.rg.location`, only the resource group location needs to be updated.

## screenshot of Terraform apply output showing successful deployment and outputs
> ![alt text](asset/Screenshot-2026-05-08_082115.png)
> ![alt text](asset/Screenshot-2026-05-08_082536.png)
---

## Phase 4 — Set Up the VM

### Step 9 — SSH into the VM

```bash
# Get VM public IP
az vm show -d -g rg-php-devops -n php-vm --query publicIps -o tsv

# Connect
ssh azureuser@YOUR_PUBLIC_IP
```

## screenshot of successful SSH connection to Azure VM in terminal
> ![alt text](asset/Screenshot-2026-05-08_082615.png)


### Step 10 — Install Docker on the VM

```bash
sudo apt update
sudo apt install docker.io -y
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker azureuser
```

### Step 11 — Install Nginx and Certbot

```bash
sudo apt install nginx certbot python3-certbot-nginx -y
sudo systemctl enable nginx
sudo systemctl start nginx
```

---

## Phase 5 — Configure GitHub Actions CI/CD

### Step 12 — Create `.github/workflows/deploy.yml`

```yaml
name: Deploy PHP App

on:
  push:
    branches:
      - main

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v3

      - name: Deploy to VM
        uses: appleboy/ssh-action@v0.1.6
        with:
          host: ${{ secrets.VM_HOST }}
          username: ${{ secrets.VM_USER }}
          key: ${{ secrets.SSH_PRIVATE_KEY }}
          script: |
            sudo rm -rf devops-deployment
            sudo git clone https://github.com/YOUR_USERNAME/devops-deployment.git
            cd devops-deployment/charitize
            sudo docker build -t php-app .
            sudo docker stop php-app || true
            sudo docker rm php-app || true
            sudo docker run -d -p 3000:80 --restart always --name php-app php-app
            sudo systemctl reload nginx
```

> **Remember:** Replace `YOUR_USERNAME/devops-deployment` with your actual GitHub repo URL on the `git clone` line.

### Step 13 — Add GitHub Secrets

Go to **GitHub → Settings → Secrets and variables → Actions → New repository secret** and add:

| Secret Name | Value |
|---|---|
| `VM_HOST` | VM public IP from Terraform output |
| `VM_USER` | `azureuser` |
| `SSH_PRIVATE_KEY` | Contents of `~/.ssh/id_rsa` (full private key including header and footer) |

**To get the SSH private key value:**

```bash
cat ~/.ssh/id_rsa
```

Copy the **entire output** including `-----BEGIN OPENSSH PRIVATE KEY-----` and `-----END OPENSSH PRIVATE KEY-----` and paste it into the secret.

## screenshot of GitHub Secrets configuration
> ![alt text](asset/Screenshot-2026-05-08_083147.png)
---

## Phase 6 — Manual Deployment Test (Verify VM is Ready)

Before relying on CI/CD, test manually to confirm the VM, Docker, and app are working:

```bash
# SSH into VM
ssh azureuser@YOUR_PUBLIC_IP

# Clone and deploy manually
sudo git clone https://github.com/YOUR_USERNAME/devops-deployment.git
cd devops-deployment/charitize
sudo docker build -t php-app .
sudo docker run -d -p 3000:80 --name php-app php-app
```

Test in browser: **http://YOUR_PUBLIC_IP:3000**

If the app loads — VM, Docker, and app are all confirmed working. ✅

## screenshot of successful manual deployment

> ![alt text](asset/Screenshot-2026-05-08_083247.png)
> ![alt text](asset/Screenshot-2026-05-08_083440.png)
> ![alt text](asset/Screenshot-2026-05-08_083724.png)
> ![alt text](asset/Screenshot-2026-05-08_083738.png)
> ![alt text](asset/Screenshot-2026-05-08_083903.png)
> ![alt text](asset/Screenshot-2026-05-08_083940.png)

---

## Phase 7 — Trigger CI/CD Pipeline

Make a visible change to test auto-deployment:

```bash
# Edit index.php — add Your Techie Hub branding
# Then push:
git add .
git commit -m "Test CI/CD"
git push origin main
```

Go to **GitHub → Actions** and watch the workflow run. Once complete, visit **http://YOUR_PUBLIC_IP:3000** — the change is live automatically.

## screenshot of successful GitHub Actions workflow run and updated app in browser
> ![alt text](asset/Screenshot-2026-05-08_084256.png)
> ![alt text](asset/Screenshot-2026-05-08_085332.png)

---

## Phase 8 — Configure DNS

At your domain registrar (Qservers, Namecheap, GoDaddy), add:

| Type | Host | Value |
|---|---|---|
| `A` | `app` | `YOUR_VM_PUBLIC_IP` |

Wait 5–30 minutes for DNS propagation, then test:
```
http://app.yourtechiehub.com.ng
```
## screenshot of DNS configuration and successful access via custom domain
> ![alt text](asset/Screenshot-2026-05-08_085454.png)
> ![alt text](asset/Screenshot-2026-05-08_085558.png)
---

## Phase 9 — Enable HTTPS

### Step 14 — Configure Nginx as reverse proxy

```bash
sudo python3 -c "
content = '''server {
    listen 80;
    listen [::]:80;
    server_name app.yourtechiehub.com.ng;
    return 301 https://\$host\$request_uri;
}
server {
    listen 443 ssl;
    listen [::]:443 ssl;
    server_name app.yourtechiehub.com.ng;
    ssl_certificate /etc/letsencrypt/live/app.yourtechiehub.com.ng/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/app.yourtechiehub.com.ng/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;
    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
'''
open('/etc/nginx/sites-available/default', 'w').write(content)
print('File written successfully')
"

sudo nginx -t
sudo systemctl restart nginx
```

### Step 15 — Obtain SSL certificate

```bash
sudo certbot --nginx -d app.yourtechiehub.com.ng
```

Follow the prompts. Certbot will issue the certificate and configure auto-renewal.

Visit: **https://app.yourtechiehub.com.ng** ✅

## screenshot of successful HTTPS access and Certbot output
> ![alt text](asset/Screenshot-2026-05-08_085655.png)
> ![alt text](asset/Screenshot-2026-05-08_090545.png)
> ![alt text](asset/Screenshot-2026-05-08_092420.png)
---

## Output

### Terraform Apply

```
Apply complete! Resources: 7 added, 0 changed, 0 destroyed.

Outputs:

vm_public_ip           = "20.x.x.x"
vm_username            = "azureuser"
ssh_connection_command = "ssh -i ~/.ssh/id_rsa azureuser@20.x.x.x"
resource_group_name    = "rg-php-devops"
```

### GitHub Actions — Successful Pipeline Run

```
======CMD======
sudo rm -rf devops-deployment
sudo git clone https://github.com/Musty2025x/devops-deployment.git
cd devops-deployment/charitize
sudo docker build -t php-app .
sudo docker stop php-app || true
sudo docker rm php-app || true
sudo docker run -d -p 3000:80 --restart always --name php-app php-app
sudo systemctl reload nginx
======END======

out: Cloning into 'devops-deployment'...
out: Successfully built a1b2c3d4e5f6
out: Successfully tagged php-app:latest
out: php-app
out: php-app
out: af94a124fab8

Finished: SUCCESS ✅
```

### Docker Container Running

```bash
docker ps
```

```
CONTAINER ID   IMAGE     COMMAND                  STATUS         PORTS
af94a124fab8   php-app   "docker-php-entrypoi…"   Up 2 minutes   0.0.0.0:3000->80/tcp
```

### SSL Certificate

```
Successfully received certificate.
Certificate is saved at: /etc/letsencrypt/live/app.yourtechiehub.com.ng/fullchain.pem
Key is saved at:         /etc/letsencrypt/live/app.yourtechiehub.com.ng/privkey.pem
This certificate expires on 2026-08-06.
Certbot has set up a scheduled task to automatically renew this certificate.

Congratulations! You have successfully enabled HTTPS on https://app.yourtechiehub.com.ng
```

### NSG Inbound Rules

| Priority | Name | Port | Protocol | Access |
|---|---|---|---|---|
| 1001 | SSH | 22 | TCP | Allow |
| 1002 | HTTP | 80 | TCP | Allow |
| 1003 | HTTPS | 443 | TCP | Allow |
| 1004 | AllowDocker | 3000 | TCP | Allow |

### GitHub Repository Secrets

| Secret | Purpose |
|---|---|
| `VM_HOST` | Azure VM public IP |
| `VM_USER` | SSH username (`azureuser`) |
| `SSH_PRIVATE_KEY` | Ed25519/RSA private key for SSH auth |

---

## Errors & Fixes

### ❌ 1 — Large files detected on GitHub (Terraform providers)

**Cause:** `.terraform/` directory containing provider binaries was committed.

**Fix:** Add `.gitignore` before the first commit. If already pushed, reset:

```bash
git init
git add .
git commit -m "Clean initial commit (no terraform cache)"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/devops-deployment.git
git push -u origin main --force
```

---

### ❌ 2 — SSH authentication failed (`no key found` / `unable to authenticate`)

**Cause 1:** `SSH_PRIVATE_KEY` secret was empty or not saved.
**Cause 2:** Public key was pasted instead of private key.
**Cause 3:** Old RSA format (`-----BEGIN RSA PRIVATE KEY-----`) incompatible with `appleboy/ssh-action`.

**Fix:** Generate a new Ed25519 key and update the secret:

```bash
ssh-keygen -t ed25519 -C "github-actions" -f ~/.ssh/github_actions_key
# Add public key to VM authorized_keys
echo "$(cat ~/.ssh/github_actions_key.pub)" >> ~/.ssh/authorized_keys
# Copy private key into SSH_PRIVATE_KEY secret
cat ~/.ssh/github_actions_key
```

---

### ❌ 3 — CI/CD succeeds but VM does not update (Permission Denied)

**Cause:** Deploy script commands were running without `sudo`.

**Fix:** Prefix all commands in the workflow script with `sudo`:

```yaml
script: |
  sudo rm -rf devops-deployment
  sudo git clone https://github.com/...
  sudo docker build -t php-app .
  sudo docker stop php-app || true
  sudo docker rm php-app || true
  sudo docker run -d -p 3000:80 --name php-app php-app
```

---

### ❌ 4 — Nginx restart failed during Certbot SSL setup (`bind() failed`)

**Cause:** Docker container was running on port 80, blocking Nginx from binding.

**Fix:** Stop the Docker container, let Nginx take port 80, then run Certbot:

```bash
sudo docker stop php-app
sudo systemctl start nginx
sudo certbot --nginx -d app.yourtechiehub.com.ng
# After cert issued, rerun Docker on port 3000:
sudo docker run -d -p 3000:80 --restart always --name php-app php-app
```

---

### ❌ 5 — App inaccessible after HTTPS setup / port conflicts

**Cause:** Nginx was serving its default page instead of proxying to the Docker container on port 3000. The `location /` block had `try_files` instead of `proxy_pass`.

**Fix:** Rewrite the Nginx config cleanly using Python (avoids shell heredoc issues):

```bash
sudo python3 -c "
content = '''server {
    ...
    location / {
        proxy_pass http://localhost:3000;
    }
}
'''
open('/etc/nginx/sites-available/default', 'w').write(content)
"
sudo nginx -t
sudo systemctl reload nginx
```

---

### ❌ 6 — `Standard_B1s` not available in West Europe

**Cause:** Azure capacity restrictions in `westeurope` region.

**Fix:** Change location to `East US` in `main.tf`:

```hcl
resource "azurerm_resource_group" "rg" {
  name     = "rg-php-devops"
  location = "East US"    # ← only line to change
}
```

Then:

```bash
terraform destroy && terraform apply
```

---

## Cleanup

```bash
# Destroy all Terraform-provisioned resources
cd terraform
terraform destroy

# Delete the auto-created NetworkWatcher resource group
az group list
az group delete -n NetworkWatcherRG -y
```
## screenshot of successful Terraform destroy output
>![alt text](asset/Screenshot-2026-05-08_093201.png)

---

## Project Summary

| Component | Detail |
|---|---|
| Application | PHP Charitize website (PHP 8.2 + Apache) |
| Container | Docker — `php-app` image — port `3000:80` |
| Infrastructure | Terraform — Azure VM (Ubuntu 22.04, Standard_B1s, East US) |
| CI/CD | GitHub Actions — SSH deploy via `appleboy/ssh-action@v0.1.6` |
| Reverse Proxy | Nginx — port 443 → localhost:3000 |
| SSL | Let's Encrypt — auto-renewed via Certbot |
| Custom Domain | `https://app.yourtechiehub.com.ng` |
| Static Public IP | Assigned via `azurerm_public_ip` (allocation: Static) |

---

## References

- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [appleboy/ssh-action](https://github.com/appleboy/ssh-action)
- [Docker — PHP Apache Image](https://hub.docker.com/_/php)
- [Certbot — Nginx](https://certbot.eff.org/instructions?ws=nginx&os=ubuntufocal)
- [Azure VM SKU Availability](https://aka.ms/azureskunotavailable)
- [Let's Encrypt](https://letsencrypt.org/)
