#
# Cookbook Name:: oradock_chef
# Recipe:: default
#
# Copyright 2016, Rafael dos Santos Mariotti
#
# All rights reserved - Do Not Redistribute
#

include_recipe 'yum'

#packages and services installation and configuration
package [node['yum']['install']] do
  action            :install
end
