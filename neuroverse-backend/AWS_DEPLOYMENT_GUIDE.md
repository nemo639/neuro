# NeuroVerse AWS Deployment Guide (Step-by-Step)

## What You Need
- AWS account (you have this)
- Your laptop with terminal/PowerShell
- ~30 minutes

---

## STEP 1: Launch EC2 GPU Instance

### 1.1 Go to AWS Console
1. Open https://console.aws.amazon.com
2. Login to your AWS account
3. Make sure you're in **Asia Pacific (Mumbai) ap-south-1** region (top-right dropdown)
   - This is closest to Pakistan = lowest latency

### 1.2 Launch Instance
1. Go to **EC2** → Click **"Launch Instance"**
2. Fill in:
   - **Name:** `neuroverse-backend`
   - **AMI:** Search for `Deep Learning AMI GPU PyTorch 2.1 (Ubuntu 22.04)`
     - This comes pre-installed with NVIDIA drivers + CUDA + Docker
     - If not found, use `Ubuntu Server 22.04 LTS` and we'll install manually
   - **Instance Type:** `g4dn.xlarge`
     - (4 vCPUs, 16GB RAM, NVIDIA T4 16GB GPU)
     - Cost: ~$0.526/hour
   - **Key Pair:** Click "Create new key pair"
     - Name: `neuroverse-key`
     - Type: RSA
     - Format: `.pem`
     - Click "Create" → **SAVE THIS FILE! You need it to connect**
   - **Network Settings:** Click "Edit"
     - Auto-assign Public IP: **Enable**
     - Security Group: Create new → Name: `neuroverse-sg`
     - Add these rules:
       | Type | Port | Source | Description |
       |------|------|--------|-------------|
       | SSH | 22 | My IP | Your access |
       | HTTP | 80 | 0.0.0.0/0 | API access |
       | HTTPS | 443 | 0.0.0.0/0 | Secure API |
       | Custom TCP | 8000 | 0.0.0.0/0 | Direct API |
   - **Storage:** 50 GB gp3 (default 8GB is too small)

3. Click **"Launch Instance"**
4. Wait 2-3 minutes for it to start

### 1.3 Get Your Public IP
1. Go to EC2 → Instances
2. Click your `neuroverse-backend` instance
3. Copy the **Public IPv4 address** (e.g., `13.234.xx.xx`)
4. **IMPORTANT:** Note this IP — you'll put it in the Flutter app

### 1.4 Get Elastic IP (So IP Doesn't Change)
1. Go to EC2 → **Elastic IPs** (left sidebar)
2. Click **"Allocate Elastic IP address"** → Allocate
3. Select the new IP → **Actions** → **Associate Elastic IP**
4. Select your `neuroverse-backend` instance → Associate
5. Now your IP is **permanent** — it won't change when you stop/start the instance

---

## STEP 2: Connect to Your Server

### From Windows (PowerShell):
```powershell
# Move the key file to a safe location
Move-Item ~/Downloads/neuroverse-key.pem ~/.ssh/neuroverse-key.pem

# Connect (replace YOUR_ELASTIC_IP)
ssh -i ~/.ssh/neuroverse-key.pem ubuntu@YOUR_ELASTIC_IP
```

### If you get "permissions too open" error:
```powershell
icacls ~/.ssh/neuroverse-key.pem /inheritance:r /grant:r "$($env:USERNAME):(R)"
```

### First time connecting:
- Type `yes` when asked about fingerprint

---

## STEP 3: Setup Server (Run These Commands on EC2)

### 3.1 Update System
```bash
sudo apt-get update && sudo apt-get upgrade -y
```

### 3.2 Install Docker (if not pre-installed)
```bash
# Check if Docker exists
docker --version

# If not installed:
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Logout and login again for group change
exit
# Then SSH back in
```

### 3.3 Install NVIDIA Container Toolkit (for GPU in Docker)
```bash
# Check if GPU is detected
nvidia-smi

# Install NVIDIA Container Toolkit
distribution=$(. /etc/os-release; echo $ID$VERSION_ID)
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.list | \
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
  sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

### 3.4 Install Docker Compose
```bash
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
docker-compose --version
```

### 3.5 Verify GPU Access in Docker
```bash
docker run --rm --gpus all nvidia/cuda:12.1.0-runtime-ubuntu22.04 nvidia-smi
```
You should see your NVIDIA T4 GPU listed.

---

## STEP 4: Upload Your Code to Server

### Option A: Using Git (Recommended)
```bash
# On your EC2 server:
cd ~
git clone https://github.com/YOUR_USERNAME/neuroverse.git
cd neuroverse/neuroverse-backend
```

### Option B: Using SCP (Direct Upload from Windows)
```powershell
# From your Windows PowerShell (NOT on EC2):
# This uploads the entire backend folder

scp -i ~/.ssh/neuroverse-key.pem -r D:\neuroverse\neuroverse-backend ubuntu@YOUR_ELASTIC_IP:~/neuroverse-backend
```

### Option C: Using FileZilla (GUI)
1. Download FileZilla: https://filezilla-project.org
2. Open Site Manager → New Site
   - Protocol: SFTP
   - Host: YOUR_ELASTIC_IP
   - User: ubuntu
   - Key file: Browse to neuroverse-key.pem
3. Connect and drag `neuroverse-backend` folder to server

---

## STEP 5: Deploy

### 5.1 Navigate to Backend
```bash
cd ~/neuroverse-backend
# or cd ~/neuroverse/neuroverse-backend (if used git)
```

### 5.2 Setup Environment File
```bash
# Edit the production env file
nano .env.production
```
- Update `SECRET_KEY` to something random and strong
- Verify DATABASE_URL is correct (Supabase)
- Save: `Ctrl+X` → `Y` → `Enter`

### 5.3 Build and Start
```bash
# Build the Docker image (takes 5-10 minutes first time)
docker-compose build

# Start everything
docker-compose up -d

# Check if running
docker-compose ps

# Check logs
docker-compose logs -f neuroverse-api
```

### 5.4 Test the API
```bash
# On the server:
curl http://localhost:8000/health

# From your laptop browser:
# Open: http://YOUR_ELASTIC_IP:8000/health
# You should see: {"status": "healthy"}
```

---

## STEP 6: Update Flutter App

Update the base URL in your Flutter app to point to AWS:

**File:** `lib/core/api_service.dart`

Change:
```dart
const url = 'https://phenological-briana-frondescent.ngrok-free.dev';
```

To:
```dart
const url = 'http://YOUR_ELASTIC_IP';
```

Then rebuild and test your Flutter app.

---

## STEP 7: Useful Commands

### Start/Stop
```bash
# Start
docker-compose up -d

# Stop
docker-compose down

# Restart
docker-compose restart

# Rebuild after code changes
docker-compose build && docker-compose up -d
```

### View Logs
```bash
# All logs
docker-compose logs -f

# Only API logs
docker-compose logs -f neuroverse-api

# Last 100 lines
docker-compose logs --tail=100 neuroverse-api
```

### Check GPU Usage
```bash
nvidia-smi
# Watch GPU usage in real-time:
watch -n 1 nvidia-smi
```

### Update Code
```bash
# If using git:
cd ~/neuroverse/neuroverse-backend
git pull
docker-compose build && docker-compose up -d

# If using SCP: re-upload files, then rebuild
```

---

## COST Management (IMPORTANT!)

### Daily Cost
- g4dn.xlarge running 24/7 = ~$12.60/day = ~$380/month

### Save Money
```bash
# STOP the instance when not using (from AWS Console):
# EC2 → Instances → Select → Instance State → Stop
# You only pay ~$0.40/day for stopped instance (storage only)

# START when needed:
# EC2 → Instances → Select → Instance State → Start
```

### For Defense Day
1. Start instance 1 day before → test everything works
2. Run during defense
3. Stop after defense

### Budget-Friendly Alternative
- Use `g4dn.xlarge` only for defense day
- Use `t3.medium` ($0.04/hr) for daily development/testing (CPU only, slower inference but works)

---

## Troubleshooting

### "Cannot connect to server"
```bash
# Check if container is running
docker-compose ps

# Check security group allows port 80/8000
# AWS Console → EC2 → Security Groups → Check inbound rules
```

### "GPU not detected"
```bash
# Check NVIDIA driver
nvidia-smi

# Check Docker GPU access
docker run --rm --gpus all nvidia/cuda:12.1.0-runtime-ubuntu22.04 nvidia-smi
```

### "Out of disk space"
```bash
# Check disk
df -h

# Clean Docker cache
docker system prune -a
```

### "Container crashes"
```bash
# Check what went wrong
docker-compose logs --tail=200 neuroverse-api

# Common: .env.production missing or wrong DATABASE_URL
```
