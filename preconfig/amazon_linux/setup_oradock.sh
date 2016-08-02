oradock_home=/opt/oradock
chef_base=/root

source ~/.bash_profile
cd ${chef_base}/chef-repo
knife cookbook create oradock_chef

cp ${oradock_home}/preconfig/amazon_linux/chef_config/attributes/oradock.rb ${chef_base}/chef-repo/cookbooks/oradock_chef/attributes/oradock.rb
cp ${oradock_home}/preconfig/amazon_linux/chef_config/recipes/*.rb ${chef_base}/chef-repo/cookbooks/oradock_chef/recipes/
cp ${oradock_home}/preconfig/amazon_linux/chef_config/metadata.rb ${chef_base}/chef-repo/cookbooks/oradock_chef/metadata.rb

cd ${chef_base}/chef-repo/cookbooks/
knife cookbook site download yum
knife cookbook site download filesystem
knife cookbook site download lvm 1.1.0
yum install git.x86_64 -y
git clone https://github.com/rafaelmariotti/chef-pyenv.git ${chef_base}/chef-repo/cookbooks/pyenv
tar -xzf ${chef_base}/chef-repo/cookbooks/yum-*
tar -xzf ${chef_base}/chef-repo/cookbooks/filesystem-*
tar -xzf ${chef_base}/chef-repo/cookbooks/lvm-*

mv ${chef_base}/chef-repo/cookbooks/yum-* ${chef_base}/chef-repo/cookbooks/yum
mv ${chef_base}/chef-repo/cookbooks/filesystem-* ${chef_base}/chef-repo/cookbooks/filesystem
mv ${chef_base}/chef-repo/cookbooks/lvm-* ${chef_base}/chef-repo/cookbooks/lvm

cp ${oradock_home}/preconfig/amazon_linux/chef_config/oradock.json ${chef_base}/oradock.json
chef-solo -c ${chef_base}/chef-repo/solo.rb -j ${chef_base}/oradock.json
