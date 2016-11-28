#backup and data settings - configure your backup and data directories and their respective devices
default['backup']['directory'] = '/backup'
default['backup']['device']    = '/dev/sdb'
default['data']['directory']   = '/data'
default['data']['device']      = '/dev/sdc'


#python settings - DO NOT CHANGE THIS
default['pyenv']['version']   = '3.5.1'
default['pyenv']['root_path'] = '/root/.pyenv'
default['pyenv']['default_modules']   = 'boto docopt'
default['pyenv']['docker_module'] = 'docker-py'
default['pyenv']['docker_module_version'] = '1.9.0'


#yum settings - DO NOT CHANGE THIS
default['yum']['install'] = 'wget.x86_64','git.x86_64','patch.x86_64','gcc44.x86_64','zlib.x86_64','zlib-devel.x86_64','bzip2.x86_64','bzip2-devel.x86_64','sqlite.x86_64','sqlite-devel.x86_64','openssl.x86_64','openssl-devel.x86_64'
