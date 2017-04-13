#!/bin/bash
oradock_home=/opt/oradock
chef_base=/root

source ~/.bash_profile

#download and install chef
wget https://packages.chef.io/files/stable/chefdk/1.3.40/el/7/chefdk-1.3.40-1.el7.x86_64.rpm
rpm -ivh chefdk-1.3.40-1.el7.x86_64.rpm
rm -f chefdk-1.3.40-1.el7.x86_64.rpm

#configure chef
mkdir -p ${chef_base}/chef-repo/cookbooks
mkdir -p ${chef_base}/chef-repo/.chef

echo "cookbook_path [ '${chef_base}/chef-repo/cookbooks' ]" > ${chef_base}/chef-repo/.chef/knife.rb
echo -e "file_cache_path \"${chef_base}/chef-solo\"\ncookbook_path \"${chef_base}/chef-repo/cookbooks\"" > ${chef_base}/chef-repo/solo.rb
