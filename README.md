# Dynamic DNS Update Script with Cloudflare API

This script automates the process of updating or creating DNS records for subdomains (and optionally the main domain) using Cloudflare's API. It checks the current public IP address and updates the DNS records accordingly, making it suitable for dynamic DNS (DDNS) setups.

## Features:

- Automatically detects the current public IP.
- Updates existing DNS records if the IP has changed.
- Creates new DNS records if they don't exist.
- Supports updating multiple subdomains.
- Optionally updates the main domain (apex domain).

## Requirements:

- bash (tested on Linux/macOS).
- curl (for making API requests).
- sed, grep (for text parsing).
- dig (for checking DNS records)
- A valid [Cloudflare API token](https://developers.cloudflare.com/fundamentals/api/get-started/create-token/) that has the permission to edit DNS for your zone.

## Setup

Clone the repository.

```shell
cp config.example.sh config.sh
```

Edit `config.sh` with your Cloudflare API token, zone ID, and domains.

## Crontab

```
crontab -e

21 * * * * /home/user/projects/cloudflare-dns-update-bash-script/cloudflare-dns-update.sh >> /home/user/projects/cloudflare-dns-update-bash-script/dns.log 2>&1
```
