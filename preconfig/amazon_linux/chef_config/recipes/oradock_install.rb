#
# Cookbook Name:: oradock
# Recipe:: default
#
# Copyright 2016, Rafael dos Santos Mariotti
#
# All rights reserved - Do Not Redistribute
#

#oradock config - download
git '/opt/oradock' do
  repository            'https://github.com/rafaelmariotti/oradock.git'
  checkout_branch       'master'
  action                        :sync
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
