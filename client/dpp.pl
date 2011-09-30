#!/usr/bin/perl
use lib '../lib/';              # include local libs
use strict;
use warnings;
use Carp qw(cluck croak carp confess);
use POSIX qw/strftime/;
use Config::General;
use DPP::VCS::Git;
use LWP::Simple;
use Data::Dumper;
use Digest::SHA qw(sha1_hex);

our $VERSION = '0.01';
my $c = new Config::General(-ConfigFile => '/etc/dpp.conf',
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
my $date_format = '%Y/%m/%d %T%z';
if (defined($cfg->{'pid_file'})) {
    open(PID, '>', $cfg->{'pid_file'});
    print PID $$;
    close(PID);
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
my $repover_hash;
my $repover_hash_old;
while ( sleep int($cfg->{'poll_interval'}) ) {
    my $status = 'no changes';
    # TODO use normal LWP, send facter data, check branch only not whole file
    my $repo_branches = get($cfg->{'puppet_repo_check_url'});
    if ( !defined($repo_branches) ) {
        $status = "GET failed";
        warn("GET of " . $cfg->{'puppet_repo_check_url'} . " failed");
        next;
    }
    my $repover_hash = sha1_hex($repo_branches);
    # fix: use branch head hash instead
    if ($repover_hash_old ne $repover_hash) {
        $status = 'new commit';
        $repover_hash_old = $repover_hash;
        debug("pooler indicates commit (config hash $repover_hash), downloading");
        debug("DUMMY we will run puppet checks here");
        $p_repo->pull;
        debug("Running Puppet");
        #        system("puppetd --test --noop --confdir=" . $cfg->{'puppet_repo_dir'});
        system('puppet',  'apply', '-v',
               "--modulepath=$cfg->{'puppet_repo_dir'}/puppet/modules/",
               $cfg->{'puppet_repo_dir'} . '/puppet/manifests/site.pp');


        debug("Puppet run finished");
        #               "--config-version=git log -1 --abbrev-commit --format='$version_format'",
    }
    if ( defined($cfg->{'status_file'}) ) {
        open(STATUS, '>', $cfg->{'status_file'});
        print STATUS $status;
        close(STATUS);
    }
}

# TODO real logging
sub err {
    my $msg = shift;
    my $date = strftime($date_format, localtime);
    print STDERR "$date err: " . $msg . "\n";
}
sub warn {
    my $msg = shift;
    my $date = strftime($date_format, localtime);

    print STDERR "$date warn: " . $msg . "\n";
}
sub debug {
    my $msg = shift;
    my $date = strftime($date_format, localtime);
    print STDERR "$date debug: " . $msg . "\n";
}
