#
# Cookbook Name:: oradock_chef
# Recipe:: default
#
# Copyright 2016, Rafael dos Santos Mariotti
#
# All rights reserved - Do Not Redistribute
#

include_recipe 'yum'
include_recipe 'pyenv'
include_recipe 'filesystem'

#mount backup and data directories
directory node['backup']['directory'] do
  owner             'root'
  group             'root'
  mode              '775'
  action            :create
end

directory node['data']['directory'] do
  owner             'root'
  group             'root'
  mode              '775'
  action            :create
end

filesystem 'backup' do
  fstype            'xfs'
  device            node['backup']['device']
  mount             node['backup']['directory']
  force             true
  action            [:create, :enable, :mount]
end

filesystem 'data' do
  fstype            'xfs'
  device            node['data']['device']
  mount             node['data']['directory']
  force             true
  action            [:create, :enable, :mount]
end

#packages and services installation and configuration
package [node['yum']['install']] do
  action			:install
end

execute 'docker_install' do
  command			'wget -qO- https://get.docker.com/ | sh'
  action			:run
end

service 'docker' do
  action			:start
end

#pyenv config
git '/root/.pyenv' do
  repository		'https://github.com/yyuu/pyenv.git'
#  checkout_branch	'master'
  action			:checkout
end

ruby_block 'config_pyenv' do
  block do
    file = Chef::Util::FileEdit.new('/root/.bash_profile')
    file.insert_line_if_no_match('export PYENV_ROOT=', 'export PYENV_ROOT="$HOME/.pyenv"')
    file.insert_line_if_no_match('export PATH="\$PYENV_ROOT', 'export PATH="$PYENV_ROOT/bin:$PATH"')
    file.insert_line_if_no_match('eval "\$\(pyenv', 'eval "$(pyenv init -)"')
    file.write_file
  end
end

pyenv_python node['pyenv']['version'] do
  root_path			node['pyenv']['root_path']
  action			:install
end

pyenv_global node['pyenv']['version'] do
  root_path			node['pyenv']['root_path']
  action			:create
end

pyenv_script 'pip_install_oradock_dependencies' do
  pyenv_version		node['pyenv']['version']
  root_path			node['pyenv']['root_path']
  code				'pip install --upgrade pip'
end

#python modules installation
pyenv_script 'pip_install_oradock_dependencies' do
  pyenv_version		node['pyenv']['version']
  root_path			node['pyenv']['root_path']
  code				'pip install ' + node['pyenv']['modules']
end

#oradock config - download
git '/opt/oradock' do
  repository		'https://github.com/rafaelmariotti/oradock.git'
  checkout_branch	'master'
  action			:sync
end

#oradock config - sysctl.conf
ruby_block 'config_sysctl.conf' do
  block do
    file = Chef::Util::FileEdit.new('/etc/sysctl.conf')
    file.insert_line_if_no_match('# oradock settings', "\n\# oradock settings")
    file.insert_line_if_no_match('net.ipv4.ip_forward = 1', 'net.ipv4.ip_forward = 1')
    file.insert_line_if_no_match('net.core.rmem_default = 16777216', 'net.core.rmem_default = 16777216')
    file.insert_line_if_no_match('net.core.rmem_max = 67108864', 'net.core.rmem_max = 67108864')
    file.insert_line_if_no_match('net.core.wmem_default = 16777216', 'net.core.wmem_default = 16777216')
    file.insert_line_if_no_match('net.core.wmem_max = 67108864', 'net.core.wmem_max = 67108864')
    file.write_file
  end
end
