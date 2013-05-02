package { [
           'libev-perl',
           'libfile-slurp-perl',
           'libdigest-sha-perl',
           'libyaml-libyaml-perl',
           'libjson-xs-perl',
           'libanyevent-perl',
           'libanyevent-http-perl',
           'liblog-any-perl',
           'ruby-hiera-puppet',
           'liblog-any-adapter-dispatch-perl',]:
               ensure => installed,
}

exec {'checkout-repo':
    # use http, most "compatible" with crappy firewall/corporate networks
    command => '/bin/bash -c "cd /usr/src;git clone http://github.com/XANi/dpp.git"',
    creates => '/usr/src/dpp/.git/config',
    logoutput => true,
}

#dummy hiera config

$hiera_cfg = '
# dummy hiera config
---
:backends:
  - yaml

:logger: console

# hack around not being able to specify more than one datadir, at least till they fix it

:hierarchy:
  - test/%{hostname}

:yaml:
    :datadir: /path/to/hiera/dir
'

file {[
       '/etc/hiera.yaml',
       '/etc/puppet/hiera.yaml',
       ]:
           mode    => 644,
           owner   => root,
           content => $hiera_cfg,
}
