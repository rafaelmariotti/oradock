#
# Cookbook Name:: oradock_chef
# Recipe:: default
#
# Copyright 2016, Rafael dos Santos Mariotti
#
# All rights reserved - Do Not Redistribute
#

include_recipe 'yum'

include_recipe 'oradock_chef::mount_fs'

#packages and services installation and configuration
package [node['yum']['install']] do
  action			:install
end

include_recipe 'oradock_chef::docker_install'

include_recipe 'oradock_chef::pyenv_install'
include_recipe 'oradock_chef::pyenv_configure'

include_recipe 'oradock_chef::oradock_install'
