#
# Cookbook Name:: oradock
# Recipe:: default
#
# Copyright 2016, Rafael dos Santos Mariotti
#
# All rights reserved - Do Not Redistribute
#

execute 'docker_install' do
  command                       'wget -qO- https://get.docker.com/ | sh'
  action                        :run
end

service 'docker' do
  action                        :start
end
