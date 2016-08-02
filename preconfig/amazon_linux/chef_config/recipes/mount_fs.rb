#
# Cookbook Name:: oradock_chef
# Recipe:: default
#
# Copyright 2016, Rafael dos Santos Mariotti
#
# All rights reserved - Do Not Redistribute
#

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

