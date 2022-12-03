#!/bin/bash

## check apt upto date
apt update
apt install -y awscli
apt install -y net-tools
apt install -y software-properties-common

## set timezone
timedatectl set-timezone Africa/Johannesburg

## load admin config to environment variables
cd /home/ubuntu
echo ${OLARM_CONFIG} | base64 --decode | gunzip > olarm_config1.env
sed 's/\#/\\\#/g' olarm_config1.env | sed 's/"/\\"/g' | tr '\n' ' ' | sed 's/ //g' > olarm_config2.env
echo '' >> /home/ubuntu/.profile
echo -n 'export OLARM_CONFIG_ADMIN="' >> /home/ubuntu/.profile
cat olarm_config2.env >> /home/ubuntu/.profile
echo '"' >> /home/ubuntu/.profile
rm olarm_config1.env olarm_config2.env

## load NODE_ENV to environment variables
echo "export NODE_ENV=production" >> /home/ubuntu/.profile

## run rest not as root user
su ubuntu <<EOSU
## check in home dir
cd /home/ubuntu

## load profile for env vars
source ~/.profile

## setup logrotate
sudo printf "/home/ubuntu/process/*.log {\nrotate 90\ndaily\nmissingok\nnotifempty\ncompress\ncopytruncate\ncreate 0640 ubuntu ubuntu\n}\n" > /etc/logrotate.d/olarm-services
mkdir /home/ubuntu/process

## NPM API Key for private NPM modules
echo "//registry.npmjs.org/:_authToken=${NPM_API_KEY}" > .npmrc

## Github Deploy Key
echo ${GITHUB_OLARM_FRONTEND_DEPLOY_KEY} | base64 --decode | gunzip > ./.ssh/id_rsa_frontend_github1
##echo ${GITHUB_OLARM_SCHEDULER_DEPLOY_KEY} | base64 --decode | gunzip > ./.ssh/id_rsa_scheduler_github1
chmod 600 /home/ubuntu/.ssh/id_rsa_front_github1
# chmod 600 /home/ubuntu/.ssh/id_rsa_scheduler_github1
echo "Host github.com
 HostName github.com
 IdentityFile ~/.ssh/id_rsa_frontend_github1
# Host scheduler.github.com
#  HostName github.com
#  IdentityFile ~/.ssh/id_rsa_scheduler_github1
" > ./.ssh/config
chmod 600 /home/ubuntu/.ssh/config

## Setup github actions directories
mkdir -p /home/ubuntu/actions-runner/_work/olarm-admin/olarm-frontend
# mkdir -p /home/ubuntu/actions-runner/_work/olarm-scheduler/olarm-scheduler

## Ansible
sudo add-apt-repository --yes --update ppa:ansible/ansible > ansible-output-setup1.log
sudo apt install -y ansible > ansible-output-setup2.log
ansible-galaxy collection install community.general > ansible-output-setup3.log
aws s3 cp s3://olarm-ansible-playbooks1/ansible-production-admin-v1.yml ./ansible-init.yml --region af-south-1
ansible-playbook ansible-init.yml > ansible-output-init.log

## Startup PM2
pm2 start /home/ubuntu/actions-runner/_work/olarm-admin/olarm-admin/api/server.js --name=api --output=/home/ubuntu/process/api.log --error=/home/ubuntu/process/api.log
pm2 start /home/ubuntu/actions-runner/_work/olarm-admin/olarm-admin/web/server.js --name=web --output=/home/ubuntu/process/web.log --error=/home/ubuntu/process/web.log
pm2 start /home/ubuntu/actions-runner/_work/olarm-scheduler/olarm-scheduler/server.js --name=scheduler --output=/home/ubuntu/process/olarm-scheduler.log --error=/home/ubuntu/process/olarm-scheduler.log
pm2 stop scheduler
pm2 save
sudo env PATH=$PATH:/usr/bin /usr/lib/node_modules/pm2/bin/pm2 startup systemd -u ubuntu --hp /home/ubuntu

## Setup Nginx
sudo apt-get install -y nginx
sudo aws s3 cp s3://olarm-nginx-configs1/nginx-production-admin-api-v1.yml /etc/nginx/sites-available/kantoor-api.olarm.tech --region af-south-1
sudo aws s3 cp s3://olarm-nginx-configs1/nginx-production-admin-web-v1.yml /etc/nginx/sites-available/kantoor.olarm.tech --region af-south-1
sudo rm /etc/nginx/sites-enabled/default
sudo ln -s /etc/nginx/sites-available/kantoor-api.olarm.tech /etc/nginx/sites-enabled/kantoor-api.olarm.tech
sudo ln -s /etc/nginx/sites-available/kantoor.olarm.tech /etc/nginx/sites-enabled/kantoor.olarm.tech
sudo service nginx reload

## Lets Encrypt
# sudo apt install -y certbot python3-certbot-nginx
# sudo certbot --nginx -d kantoor.olarm.tech -d kantoor-api.olarm.tech --non-interactive --agree-tos -m info@olarm.co --redirect
# sudo systemctl status certbot.timer

## set cron to clear reports
crontab -l | { cat; echo "5 5 * * * /usr/bin/find /home/ubuntu/actions-runner/_work/olarm-scheduler/olarm-scheduler/reports -mindepth 1 -maxdepth 1 -type f -mtime +3 -delete"; } | crontab -
EOSU

## upgrade!
apt upgrade
