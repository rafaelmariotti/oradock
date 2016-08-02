name             'oradock'
maintainer       'Rafael dos Santos Mariotti'
maintainer_email 'rafael.s.mariotti@gmail.com'
license          'All rights reserved'
description      'Installs/Configures oradock'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          '0.1.0'

depends "yum"
depends "filesystem"
depends "lvm"
depends "pyenv"
