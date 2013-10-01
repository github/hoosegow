# Hoosegow

A Docker based aproach to rendering.

## Install on Ubuntu 12.04

#### 1. Install Docker

```bash
sudo apt-get update
sudo apt-get install linux-image-generic-lts-raring linux-headers-generic-lts-raring curl
sudo reboot
```

**Go get a beer while Ubuntu reboots.**

```bash
  sudo sh -c "curl https://get.docker.io/gpg | apt-key add -"
  sudo sh -c "echo deb http://get.docker.io/ubuntu docker main > /etc/apt/sources.list.d/docker.list"
  sudo apt-get update
  sudo apt-get install lxc-docker
```

#### 2. Build hoosegow image

```bash
sudo script/bootstrap-docker
```
