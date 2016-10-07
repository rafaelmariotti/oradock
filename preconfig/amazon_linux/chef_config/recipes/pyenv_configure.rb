#
# Cookbook Name:: oradock
# Recipe:: default
#
# Copyright 2016, Rafael dos Santos Mariotti
#
# All rights reserved - Do Not Redistribute
#

include_recipe 'pyenv'

#python and modules install
pyenv_python node['pyenv']['version'] do
  root_path                     node['pyenv']['root_path']
  action                        :install
end

pyenv_global node['pyenv']['version'] do
  root_path                     node['pyenv']['root_path']
  action                        :create
end

pyenv_script 'pip_install_upgrade_pip' do
  pyenv_version         node['pyenv']['version']
  root_path                     node['pyenv']['root_path']
  code                          'pip install --upgrade pip'
end

pyenv_script 'pip_install_oradock_default_dependencies' do
  pyenv_version		node['pyenv']['version']
  root_path		node['pyenv']['root_path']
  code			'pip install ' + node['pyenv']['default_modules']
end

pyenv_script 'pip_install_oradock_dockerpy_dependenciess' do
  pyenv_version     node['pyenv']['version']
  root_path     node['pyenv']['root_path']
  code          'pip install ' + node['pyenv']['docker_module'] + '==' + node['pyenv']['docker_module_version']
end
