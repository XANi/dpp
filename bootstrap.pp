package { [
           'libev-perl',
           'libfile-slurp-perl',
           'libdigest-sha-perl',
           'libyaml-libyaml-perl',
           'libanyevent-perl',
           'libanyevent-http-perl',
           'liblog-any-perl',
           'liblog-any-adapter-dispatch-perl',]:
               ensure => installed,
}

exec {'checkout-repo':
    # use http, most "compatible" with crappy firewall/corporate networks
    command => '/bin/bash -c "cd /usr/src;git clone http://github.com/XANi/dpp.git"',
    creates => '/usr/src/dpp/.git/config',
    logoutput => true,
}
