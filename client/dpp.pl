#!/usr/bin/perl
use lib '../lib/';              # include local libs
use strict;
use warnings;
use Carp qw(cluck croak carp confess);
use POSIX qw/strftime/;
use Config::General;
use DPP::VCS::Git;
use LWP::Simple;
use File::Slurp;
use YAML;
use Data::Dumper;
use Digest::SHA qw(sha1_hex);
use File::Path qw (mkpath);

our $VERSION = '0.01';
my $yaml = read_file('/etc/dpp.conf');
my $cfg = Load($yaml) or croak($!);


# simple validate of config vars, TODO make better


my @validate = (
                'repo',
			);

foreach my $cfg_option (@validate) {
    if ( !defined($cfg->{$cfg_option}) ) {
        croak ("Essential variable $cfg_option not defined in config!!!");
    }
}
my $date_format = '%Y/%m/%d %T%z';
if (defined($cfg->{'pid_file'})) {
    open(PID, '>', $cfg->{'pid_file'});
    print PID $$;
    close(PID);
}
# defaults
$cfg->{'repo_dir'} ||= '/var/lib/dpp/repos';
$cfg->{'hiera_dir'} ||= '/var/lib/dpp/hiera';
$cfg->{'poll_interval'} ||= 60;
$cfg->{'on_change_min_wait'} ||= 120;

if ( ! -e $cfg->{'hiera_dir'} ) {mkpath($cfg->{'hiera_dir'},1,700) or die($!)}
if ( ! -e $cfg->{'repo_dir'} ) {mkpath($cfg->{'repo_dir'},1,700) or die($!)}


if ($cfg->{'poll_interval'} < 1) {
    carp {'poll_interval have to be > 1'};
}

# init
print Dumper $cfg;

my $puppet_module_path = &generate_module_path;
my $puppet_main_repo = $cfg->{'repo_dir'} . '/shared';

my $repos = {};
while (my ($repo, $repo_config) = each ( %{ $cfg->{'repo'} } ) ) {
    my $repo_path = $cfg->{'repo_dir'} . '/' . $repo;
    if (!defined($repo_config->{'force'})) {
        $repo_config->{'force'}=0;
    }
    my $p_repo = DPP::VCS::Git->new(
        git_dir => $repo_path,
        force => $repo_config->{'force'}
    );
    if ( !$p_repo->validate() ) {
        $p_repo->create($repo_config->{'pull_url'});
        $p_repo->validate() or croak("validate of dpp_puppet repo failed after cloning from " . $repo_config->{'pull_url'});
    }
    $repos->{$repo}{'object'} = $p_repo;
    $repos->{$repo}{'hash'} = '';
	if( defined( $repo_config->{'hiera_dir'} ) ) {
		&ensure_link($repo_path . '/' . $repo_config->{'hiera_dir'}, $cfg->{'hiera_dir'} . '/' . $repo);
	}
}
# now either repo should be ready or we died
my $repover_hash;
my $repover_hash_old;
my $last_run=0;
while ( sleep int($cfg->{'poll_interval'}) ) {
    my $status;
    my $run=0;
    while ( my ($repo_name, $repo) = each (%$repos) ) {
        &info("Checking $repo_name");
        # TODO not dumb check url
        my $get = get( $cfg->{'repo'}{$repo_name}{'check_url'} ) or carp ($?) ;
        my $hash = sha1_hex($get);
        &debug("  H:$hash");
        if ($hash ne $repo->{'hash'}) {
            $repo->{'hash'} = $hash;
            $repo->{'object'}->pull;
            $repo->{'object'}->checkout( $cfg->{'repo'}{$repo_name}{'branch'} );
            $run = 1;
            $status .= "new commit in $repo_name  # ";
        }
    }
    if ($run < 1) {
        next #nothing to run
    }
    debug("DUMMY we will run puppet checks here");
    &run_puppet;
    if ( defined($cfg->{'status_file'}) ) {
        open(STATUS, '>', $cfg->{'status_file'});
        print STATUS $status;
        close(STATUS);
    }
    $last_run=time();
}

sub run_puppet {
    debug("Running Puppet");
    #        system("puppetd --test --noop --confdir=" . $cfg->{'puppet_repo_dir'});
    system('puppet',  'apply', '-v',
           "--modulepath=$puppet_module_path" ,
           $puppet_main_repo . '/puppet/manifests/site.pp');
    debug("Puppet run finished");
}

sub generate_module_path {
    my @puppet_module_path;
    foreach(@{ $cfg->{'use_repos'} }) {
        push(@puppet_module_path, $cfg->{'repo_dir'} . '/' . $_ . '/modules');
    }
    return join(':',@puppet_module_path);
}


# TODO real logging
sub info {
    my $msg = shift;
    my $date = strftime($date_format, localtime);
    print STDERR "$date info: " . $msg . "\n";
}
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
    if( defined($cfg->{'debug'} ) ) {
        my $date = strftime($date_format, localtime);
        print STDERR "$date debug: " . $msg . "\n";
    }
}
sub ensure_link {
	my $source = shift;
	my $target = shift;
	$source =~ s/\/$//;
	$target =~ s/\/$//;
	if (! -e $source) {
		croak("Link source $source does not exist!");
	}
	if (! -e $target) {
		symlink($source, $target);
		debug("Hiera symlink $target => $source does not exist => created");
		return
	}

	if (-l $target) {
		my (undef, $source_inode) = stat($source);
		my (undef, $target_inode) = stat($target);
		if ($source_inode eq $target_inode) {
			debug("Hiera symlink $target => $source OK");
		} else {
			debug("Hiera symlink pointing to wrong dir, relinkin $target => $source");
			unlink($target);
			symlink($source, $target);
		}
	} else {
		croak ("Can't create hiera symlink, target $target isn't a symlink, remove it and retry");
	}
}
