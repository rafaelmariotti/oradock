#
# Cookbook Name:: oradock_chef
# Recipe:: default
#
# Copyright 2016, Rafael dos Santos Mariotti
#
# All rights reserved - Do Not Redistribute
#

include_recipe 'oradock_chef::mount_fs'

include_recipe 'oradock_chef::yum_install'

include_recipe 'oradock_chef::docker_start'

include_recipe 'oradock_chef::pyenv_install'

include_recipe 'oradock_chef::pyenv_configure'

include_recipe 'oradock_chef::oradock_install'
