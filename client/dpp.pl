#!/usr/bin/perl
use lib '../lib/';              # include local libs
use strict;
use warnings;
use Carp qw(cluck croak carp confess);
use POSIX qw/strftime/;

use EV;
use AnyEvent;
use AnyEvent::HTTP;

use Config::General;
use File::Slurp;
use YAML;
use Data::Dumper;
use Digest::SHA qw(sha1_hex);
use File::Path qw (mkpath);
use Symbol qw(gensym);
use IPC::Open3;
use Log::Any qw($log);
use Log::Any::Adapter;
use Log::Dispatch;
use Log::Dispatch::Screen;

use DPP::Agent;
use DPP::VCS::Git;



our $VERSION = '0.01';
my $yaml = read_file('/etc/dpp.conf');
my $cfg = Load($yaml) or croak($!);

my $logger = Log::Dispatch->new();
$logger->add(
    Log::Dispatch::Screen->new(
        name      => 'screen',
        min_level => 'debug',
        callbacks => (\&_log_helper_timestamp),
    )
);
Log::Any::Adapter->set( 'Dispatch', dispatcher => $logger );



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
$cfg->{'puppet'}{'start_wait'} ||= 60;
$cfg->{'puppet'}{'minimum_interval'} ||= 120;
$cfg->{'puppet'}{'schedule_run'} ||= 3600;

if ( ! -e $cfg->{'hiera_dir'} ) {mkpath($cfg->{'hiera_dir'},1,700) or die($!)}
if ( ! -e $cfg->{'repo_dir'} ) {mkpath($cfg->{'repo_dir'},1,700) or die($!)}


if ($cfg->{'poll_interval'} < 1) {
    carp {'poll_interval have to be > 1'};
}
# init
$log->debug("Config: \n" .  Dumper $cfg);

my $agent = DPP::Agent->new($cfg);

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
        $agent->ensure_link($repo_path . '/' . $repo_config->{'hiera_dir'}, $cfg->{'hiera_dir'} . '/' . $repo);
    }
}
# now either repo should be ready or we died
my $last_run=0;
my $finish = AnyEvent->condvar;
my $events;
$events->{'SIGTERM'} =
    AnyEvent->signal (
        signal => "TERM",
        cb => sub {
            $finish->send("Sigterm")
        });

my $run = 0;
while ( my ($repo_name, $repo) = each (%$repos) ) {
    $events->{"repo_checker-$repo_name"} = AnyEvent->timer(
        after => 1,
        interval => $cfg->{'poll_interval'},
        cb => sub {
            my $url = $cfg->{'repo'}{$repo_name}{'check_url'};
            $log->info("Checking $repo_name with url $url");
            http_get $url, sub {
                my $data = shift;
                my $headers = shift;
                my $hash = sha1_hex($data);
                $log->debug("$repo_name  H:$hash");
                if ($hash ne $repo->{'hash'}) {
                    $log->info("Change in repo $repo_name, scheduling puppet run");
                    $repo->{'hash'} = $hash;
                    $repo->{'object'}->pull;
                    $repo->{'object'}->checkout( $cfg->{'repo'}{$repo_name}{'branch'} );
                    $run = 1;
                }
            };
        }
    );
}
$events->{'puppet_runner'} = AnyEvent->timer(
    after => $cfg->{'puppet'}{'start_wait'},
    interval => 10,
    cb => sub {
        my $t = time;
        if ($last_run > $t) {
            $log->err("I think something changed time because last run is in the future, resetting");
            $last_run = $t;
        }
        if ( ( $last_run + $cfg->{'puppet'}{'minimum_interval'} ) > $t ) {
            return;
        }
        if ( ( $last_run + 3600 + $cfg->{'puppet'}{'schedule_run'} ) < $t ) {
            $run = 1;
        }
        if ($run > 0) {
            $agent->run_puppet;
            $run = 0;
            if ( defined($cfg->{'status_file'}) ) {
                    open(STATUS, '>', $cfg->{'status_file'});
                    print STATUS scalar time;
                    close(STATUS);
                }
            $last_run=time();
        }
    }
);

my $exit_reason = $finish->recv();
$log->info("Exiting because of <$exit_reason>");


sub _log_helper_timestamp() {
    my %a = @_;
    my $out;
    my $multiline_mark = '';
    foreach( split(/\n/,$a{'message'}) ) {
        $out .= strftime('%Y-%m-%dT%H:%M:%S%z',localtime(time)) . ' ' . $a{'level'} . ': ' . $multiline_mark . $_ . "\n";
        $multiline_mark = '.  '
    }
    return $out
}

