#!/usr/bin/perl
use lib '../lib/';              # include local libs
use strict;
use warnings;
use Carp qw(cluck croak carp confess);
use Config::General;
use DPP::VCS::Git;
use LWP::Simple;
use Data::Dumper;
our $VERSION = '0.01';
my $c = new Config::General(-ConfigFile => '/etc/dppd.conf',
                            -MergeDuplicateBlocks => 'true',
                            -MergeDuplicateOptions => 'true',
                            -AllowMultiOptions => 'true'
                           );
my %cfg = $c->getall;
my $cfg =\%cfg;
# simple validate of config vars, TODO make better
my @validate = (
                'puppet_repo',
                'puppet_repo_dir',
                'puppet_repo_check_url',
                'poll_interval',
                'on_change_min_wait',
                'poll_interval',
               );
foreach my $cfg_option (@validate) {
    if ( !defined($cfg->{$cfg_option}) ) {
        carp ("Essential variable $cfg_option not defined in config!!!");
    }
}
if ($cfg->{'poll_interval'} < 1) {
    carp {'poll_interval have to be > 1'};
}
# init
print Dumper $cfg;
my $p_repo = DPP::VCS::Git->new($cfg->{'puppet_repo_dir'});
if ( !$p_repo->validate() ) {
    $p_repo->create($cfg->{'puppet_repo'});
    $p_repo->validate() or croak("validate of dpp_puppet repo failed after cloning from " . $cfg->{'puppet_repo'});
}
# now either repo should be ready or we died
my $url_mtime;
while ( sleep int($cfg->{'poll_interval'}) ) {
    # TODO use normal LWP, send facter data
    my ($content_type, $document_length, $modified_time, $expires, $server) = head($cfg->{'puppet_repo_check_url'});
    if ( !defined($modified_time) ) {
        warn("HEAD of " . $cfg->{'puppet_repo_check_url'} . "
failed");
       next;
    }
    # fix: use branch head hash instead
    if ($url_mtime ne $modified_time) {
        $url_mtime = $modified_time;
        debug("pooler indicates new commit, downloading");
        debug("DUMMY we will run puppet checks here");
        $p_repo->pull;
        debug("Running Puppet");
#        system("puppetd --test --noop --confdir=" . $cfg->{'puppet_repo_dir'});
        system("puppet apply -v " .
               "--modulepath=$cfg->{'puppet_repo_dir'}/puppet/modules/ " .
               $cfg->{'puppet_repo_dir'} . '/puppet/manifests/site.pp');
    }
}

# TODO real logging
sub err {
    my $msg = shift;
      print STDERR 'err: ' . $msg . "\n";
}
sub warn {
    my $msg = shift;
    print STDERR 'warn: ' . $msg . "\n";
}
sub debug {
    my $msg = shift;
    print STDERR 'd: ' . $msg . "\n";
}
