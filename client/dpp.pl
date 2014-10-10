#!/usr/bin/perl
use FindBin;
use lib $FindBin::Bin . '/../lib';
use strict;
use warnings;
use Carp qw(cluck croak carp confess);
use POSIX qw/strftime/;
use Getopt::Long;
use Pod::Usage;


use EV;
use AnyEvent::HTTP;
use AnyEvent;
use Data::Dumper;
use Digest::SHA qw(sha1_hex);
use File::Path qw (make_path);
use File::Slurp;
use IPC::Open3;
use JSON::XS;
use Log::Any qw($log);
use Log::Any::Adapter;
use Log::Dispatch;
use Log::Dispatch::Screen;
use Log::Dispatch::File;
use Log::Dispatch::Syslog;
use Symbol qw(gensym);
use Term::ANSIColor qw(color colorstrip);
use YAML::XS qw(Load LoadFile Dump);

use DPP::Agent;
use DPP::Bootstrap;
use DPP::VCS::Git;

# hack around puppet derp encoding
$ENV{'LANG'}="C.UTF-8";
$ENV{'LC_ALL'}="C.UTF-8";

my $hostname = `hostname --fqdn`;
$0 = 'dpp';
chomp($hostname);


our $VERSION = '0.01';

my $help;
my $cfg;

my $cf_list = [
    'cfg/dpp.conf',
    '/etc/dpp.conf',
    'cfg/dpp.default.conf',
];
foreach my $f (@$cf_list) {
    if ( -r $f ) {
        $cfg = LoadFile($f);
        last;
    }
}
if (!defined($cfg)) {
    croak("Can't find any config in" . Dump $cf_list);
}
GetOptions(
    'help'           => \$help,
    'bootstrap=s'    => \$cfg->{'bootstrap'},
    'log-file=s'     => \$cfg->{'log'}{'file'},
    'daemonize'      => \$cfg->{'daemonize'},
    'config-dump'    => \$cfg->{'config-dump'},
    'pid-file=s'     => \$cfg->{'pid_file'},
    'checksum=s'     => \$cfg->{'checksum'},
) or pod2usage(
    -verbose => 2,  #2 is "full man page" 1 is usage + options ,0/undef is only usage
    -exitval => 1,   #exit with error code if there is something wrong with arguments so anything depending on exit code fails too
);
$cfg->{'log'}{'level'} ||= 'debug';
if ($cfg->{'log'}{'target'} eq 'stderr') {
    $cfg->{'log'}{'ansicolor'} ||= 1;
} else {
    $cfg->{'log'}{'ansicolor'} ||= 0;
}


my $logger = Log::Dispatch->new();
if (!$cfg->{'log'}{'target'}) {
    if( defined($cfg->{'log'}{'file'}) || $cfg->{'daemonize'} ) {
        $cfg->{'log'}{'target'} = 'file';
    }
    else {
        $cfg->{'log'}{'target'} = 'stderr';
    }
}
$cfg->{'log'}{'level'} ||= 'debug';
if ($cfg->{'config-dump'}) {
    print Dumper $cfg;
}
if ($cfg->{'log'}{'target'} eq 'stderr') {
    $logger->add(
        Log::Dispatch::Screen->new(
            name      => 'screen',
            min_level => $cfg->{'log'}{'level'},
            callbacks => (\&_log_helper_timestamp),
        )
      );
}
elsif ($cfg->{'log'}{'target'} eq 'file') {
    if (!defined($cfg->{'log'}{'file'})) {
        croak("log type selected as file but no file specified!");
    }
    $cfg->{'log'}{'ansicolor'} = 0;
    $logger->add(
        Log::Dispatch::File->new(
            name      => 'file',
            mode      => '>>',
            min_level => $cfg->{'log'}{'level'},
            callbacks => (\&_log_helper_timestamp),
            filename => $cfg->{'log'}{'file'},
        )
      );
}
elsif ($cfg->{'log'}{'target'} eq 'syslog') {
    $cfg->{'log'}{'ansicolor'} = 0;
    $logger->add(
        Log::Dispatch::Syslog->new(
            name      => 'syslog',
            min_level => $cfg->{'log'}{'level'},
            callbacks => (\&_log_helper),
            ident     => 'dpp',
        )
      );
}
else {
    croak("All logging methods are disabled, refusing to run");
}


Log::Any::Adapter->set( 'Dispatch', dispatcher => $logger );


if($cfg->{'bootstrap'}) {
    my $bootstrap = DPP::Bootstrap->new(
        url => $cfg->{'bootstrap'},
        checksum => $cfg->{'checksum'},
    );
    $log->notice("bootstrap complete");
    exit;
}



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
my $pid = $$;
if ($cfg->{'daemonize'}) {
    $pid = fork;
    if ($pid < 0) { croak($!); }
}

if($pid && $cfg->{'pid_file'}) {
    $log->debug('saving pidfile in ' . $cfg->{'pid_file'});
    open(P, '>', $cfg->{'pid_file'}) or die($!);
    print P $pid;
    close(P);
}

if ($pid && $cfg->{'daemonize'}) {
    exit;
}

# defaults
$cfg->{'repo_dir'} ||= '/var/lib/dpp/repos';
$cfg->{'hiera_dir'} ||= '/var/lib/dpp/hiera';
$cfg->{'poll_interval'} ||= 60;
$cfg->{'puppet'}{'start_wait'} ||= 60;
$cfg->{'puppet'}{'minimum_interval'} ||= 120;
$cfg->{'puppet'}{'schedule_run'} ||= 3600;

if ( ! -e $cfg->{'hiera_dir'} ) {make_path($cfg->{'hiera_dir'},1,700) or die($!)}
if ( ! -e $cfg->{'repo_dir'} ) {make_path($cfg->{'repo_dir'},1,700) or die($!)}


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
    $repo_config->{'gpg'} ||= undef;
    my $p_repo = DPP::VCS::Git->new(
        git_dir => $repo_path,
        force => $repo_config->{'force'},
        gpg   => $repo_config->{'gpg'},
    );
    $repo_config->{'branch'} ||= 'master';

    if ( $p_repo->validate() ) {
        $p_repo->fetch();
        $p_repo->init_submodule;
    } else {
        $p_repo->init($repo_config->{'pull_url'});
        $p_repo->fetch();
        if ($p_repo->verify_commit('remotes/origin/'. $repo_config->{'branch'} ) ) {
            $p_repo->checkout('remotes/origin/'.$repo_config->{'branch'});
            $p_repo->init_submodule;
        } else {
            $log->error("Validation of repo $repo run_ok");
        }
        $p_repo->validate() or croak("validate of dpp_puppet repo run_ok after cloning from " . $repo_config->{'pull_url'});
    }
    $repos->{$repo}{'object'} = $p_repo;
    $repos->{$repo}{'hash'} = '';
    if( defined( $repo_config->{'hiera_dir'} ) ) {
        $agent->ensure_link($repo_path . '/' . $repo_config->{'hiera_dir'}, $cfg->{'hiera_dir'} . '/' . $repo);
    }
}
# now either repo should be ready or we died
my $last_run=time() - $cfg->{'puppet'}{'minimum_interval'} + $cfg->{'puppet'}{'start_wait'};
my $finish = AnyEvent->condvar;
my $run_puppet;
my $events;
$events->{'SIGTERM'} = AnyEvent->signal (
    signal => 'TERM',
    cb => sub {
        $finish->send('Sigterm')
    }
);

$events->{'SIGUSR1'} = AnyEvent->signal(
    signal => 'USR1',
    cb => sub {
        $log->notice("Received SIGUSR1, scheduling run");
        $last_run=0;
        &schedule_run,
    },
);

&arm_puppet;

my $delayed_run = $cfg->{'puppet'}{'start_wait'} +  time(),;
while ( my ($repo_name, $repo) = each (%$repos) ) {
    $events->{"repo_checker-$repo_name"} = AnyEvent->timer(
        after => 5,
        interval => $cfg->{'poll_interval'},
        cb => sub {
            my $url = $cfg->{'repo'}{$repo_name}{'check_url'};
            if ($delayed_run > 0 && ($delayed_run - time()) < 15) {return;} # puppet is scheduled to run so dont bother with next check
            $log->info("Checking $repo_name with url $url");
            http_get $url, sub {
                my $data = shift;
                my $headers = shift;
                my $hash = sha1_hex($data);
                $log->debug("$repo_name  H:$hash");
                if ($hash ne $repo->{'hash'}) {
                    $log->notice("Change in repo $repo_name, scheduling puppet run");
                    $repo->{'hash'} = $hash;
                    $repo->{'object'}->fetch;
                    if( !$repo->{'object'}->verify_commit('remotes/origin/' . $cfg->{'repo'}{$repo_name}{'branch'} ) ) {
                        $log->error("Head of branch in repo $repo_name verification run_ok");
                        return;
                    }

                    if ( $repo->{'object'}->checkout( 'remotes/origin/' . $cfg->{'repo'}{$repo_name}{'branch'} ) ) {
                        $repo->{'object'}->update_submodule;
                        if (!defined $events->{'delayed_puppet_run'} ) {
                            $events->{'delayed_puppet_run'} = AnyEvent->timer(
                                after => 3,
                                cb => sub {
                                    delete  $events->{'delayed_puppet_run'};
                                    $log->warn("Delaying run by 3 seconds to allow other checks to finish");
                                    &schedule_run;
                                }
                            );
                        }
                        else {
                            $log->warn("Other run in progress, not scheduling another one");
                        }
                    } else {
                        # rerun, ugly hack
                        $repo->{'hash'} .= '_pull_failed';
                    }
                }
            };
        }
    );
}
$events->{'puppet_runner'} = AnyEvent->timer(
    after => 4,
    interval => 10,
    cb => sub {
        my $t = time;
        if ( ( $last_run + 3600 + $cfg->{'puppet'}{'schedule_run'} ) < $t ) {
            $log->notice("No commits in a while, periodic puppet run scheduled");
            &schedule_run;
            return;
        }
        if ( $delayed_run && ( ( $last_run + $cfg->{'puppet'}{'minimum_interval'} ) > $t ) ) {
            $log->debug("Waiting for minimal interval");
            return# still waiting for minimum interval
        }
        if ($delayed_run > 0 && $delayed_run < time()) {
            $log->debug("Running delayed run");
            &schedule_run;
            return;
        }
    }
);

my $exit_reason = $finish->recv();
$log->notice("Exiting because of <$exit_reason>");

sub arm_puppet {
    undef $run_puppet;
    $run_puppet = AnyEvent->condvar;
    $run_puppet->cb(
        sub {
            &arm_puppet;
            &run_puppet;
        }
    );
}

sub notify {
    my $notify = shift;
    if( defined( $cfg->{'exec_notify'} ) ) {
        system($cfg->{'exec_notify'}, $notify);
    }
}



sub schedule_run {
    my $t = time;
    $log->notice("Scheduling puppet");
    if ($last_run > $t) {
        $log->warn("I think something changed time because last run is in the future, resetting");
        $last_run = $t;
        return;
    }
    if ( ( $last_run + $cfg->{'puppet'}{'minimum_interval'} ) > $t ) {
        $log->notice("Below minimum interval, delaying");
        $delayed_run = 1;
        return
    }
    if ( $delayed_run > time() ) {
        $log->notice("run scheduled to start in " . $delayed_run - time());
    };
    $run_puppet->send;
}

sub run_puppet {
    if ( defined($cfg->{'status_file'}) ) {
        open(STATUS, '>', $cfg->{'status_file'});
        print STATUS scalar time;
        close(STATUS);
    }
    &notify("Running puppet");
    my $run_ok = $agent->run_puppet;
    $delayed_run = 0;
    $last_run=time();
    if (defined ($cfg->{'manager_url'}) ) {
        &send_report($run_ok);
    }
    if($run_ok) {
        &notify("Finished");
    }
    else {
        &notify("Failed");
    }
    return;
}

sub send_report {
    my $y = read_file('/var/lib/puppet/state/last_run_summary.yaml');
    my $report;
    eval {
        $report = Load($y);
    };
    if($?) {
        $log->err("Invalid YAML in /var/lib/puppet/state/last_run_summary.yaml");
        return;
    }
    $report->{'hostname'} = $hostname;
    http_post $cfg->{'manager_url'} . '/report',
        encode_json($report),
        headers => {
            'Content-encoding' => 'application/json',
        },
        timeout => 30,
        sub {
            my ($body, $hdr) = @_;
            if ($hdr->{Status} =~ /^2/) {
                $log->notice("Successfuly sent report");
            }
            else {
                my $errmsg = "Error!\n";
                if (!defined($body) || $body =~ /^\s*$/) {
                    $errmsg .= "Received empty body!\n";
                }
                $errmsg .= "Headers:" . Dump ($hdr);
                $log->error($errmsg);
            }
        };
    return;
}

sub _log_helper_timestamp {
    my %a = @_;
    my $out;
    my $multiline_mark = '';
    foreach( split(/\n/,$a{'message'}) ) {
        if ( $cfg->{'log'}{'ansicolor'} ) {
            $out .= color('bright_green') .  strftime('%Y-%m-%dT%H:%M:%S%z',localtime(time)) . color('reset') . ' ' .  &_get_color_by_level($a{'level'}) . ': ' . $multiline_mark . $_ . "\n";
        } else {
            $out .= strftime('%Y-%m-%dT%H:%M:%S%z',localtime(time)) . ' ' . $a{'level'} . ': ' . $multiline_mark . colorstrip($_) . "\n";
        }
        $multiline_mark = '.  '
   }
    return $out
}

sub _log_helper {
    my %a = @_;
    my $out;
    my $multiline_mark = '';
    foreach( split(/\n/,$a{'message'}) ) {
        $out .= $multiline_mark . $_ . "\n";
        $multiline_mark = '.  '
    }
    return $out
}

sub _get_color_by_level {
    my $level = shift;
    my $color_map = {
        debug => 'blue',
        error => 'bold red',
        warning => 'bold yellow',
        info => 'green',
        notice => 'cyan',
    };
    my $color;
    if (defined( $color_map->{$level} )) {
        $color = $color_map->{$level}
    } else {
        $color= 'green';
    }
    return color($color) . $level . color('reset');
}
