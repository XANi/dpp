#!/usr/bin/perl
use lib '../lib/'; # include local libs
use strict;
use warnings;
use Config::General;
use DPP::VCS::Git;
use LWP::Simple;
our $VERSION = '0.01';




my $c = new Config::General(-ConfigFile => '/etc/dppd.conf',
                         -MergeDuplicateBlocks => 'true',
                         -MergeDuplicateOptions => 'true',
                         -AllowMultiOptions => 'true'
			);
my %cfg = $c->getall;
my $cfg =\%cfg;

# simple validate of config vars, TODO make better
my @validate = [
		'puppet_repo',
		'puppet_repo_dir',
		'puppet_repo_check_url',
		'dppd_repo_dir',
		'poll_interval',
		'on_change_min_wait',
		'poll_interval',
];
foreach my $cfg_option (@validate) {
    if ( !defined($cfg->{$cfg_option}) ) {
	carp ("Essential variable $cfg_option not defined in config!!!");
    }
}
if($cfg->{'poll_interval'} < 1) {carp {'poll_interval have to be > 1'} }
# init
my $p_repo = DPP::VCS::Git->new($cfg->{'puppet_repo_dir'});
my $dpp_repo = DPP::VCS::Git->new($cfg->{'dppd_repo_dir'});
if( !$dpp_repo->validate) {
    $dpp_repo->create($cfg->{'puppet_repo'}, {bare => 1});
    $dpp_repo->validate() or carp("validate of dpp_puppet repo failed after cloning from " . $cfg->{'puppet_repo'});
}
if( !$p_repo->validate()) {
    $p_repo->create($cfg->{'dpp_repo_dir'});
    $p_repo->validate() or carp("validate of puppet repo failed after cloning from " . $cfg->{'dppd_repo_dir'});
}

# now either both repos should be ready or we died
my $url_mtime;
while(sleep int($cfg->{'poll_interval'})) {
    # TODO use normal LWP, send facter data
    my ($content_type, $document_length, $modified_time, $expires, $server) = head($cfg->{'puppet_repo_check_url'});
    if( !defined($modified_time) ) { 
	warn("HEAD of " . $cfg->{'puppet_repo_check_url'} . "failed");
	next
    }
    if($url_mtime ne $modified_time) {
	$url_mtime = $modified_time;
	debug("pooler indicates new commit, downloading");
	$dpp_repo->pull;
	debug("DUMMY we will run puppet checks here");
	debug("checks ok, now push changes to puppet");
	$p_repo->pull;
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
