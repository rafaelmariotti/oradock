#
# Cookbook Name:: oradock_chef
# Recipe:: default
#
# Copyright 2016, Rafael dos Santos Mariotti
#
# All rights reserved - Do Not Redistribute
#

include_recipe 'pyenv'

#pyenv config
git '/root/.pyenv' do
  repository            'https://github.com/yyuu/pyenv.git'
#  checkout_branch      'master'
  action                        :checkout
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
