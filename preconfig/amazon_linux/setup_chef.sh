oradock_home=/opt/oradock
chef_base=/root

cd ${chef_base}
wget https://www.opscode.com/chef/install.sh
bash ${chef_base}/install.sh
wget http://github.com/opscode/chef-repo/tarball/master
tar -zxf master
mv chef-chef-repo* chef-repo
rm -f master
cd ${chef_base}/chef-repo
mkdir .chef
echo "cookbook_path [ '${chef_base}/chef-repo/cookbooks' ]" > .chef/knife.rb
echo -e "file_cache_path \"${chef_base}/chef-solo\"\ncookbook_path \"${chef_base}/chef-repo/cookbooks\"" > solo.rb
