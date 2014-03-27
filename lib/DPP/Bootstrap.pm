package DPP::Bootstrap;

use 5.010000;
use common::sense;
use Carp qw(cluck croak carp);
use Data::Dumper;
use Digest::SHA qw(sha256_hex);
use Log::Any qw($log);
use YAML;
use File::Slurp qw(write_file read_file);
use Encode qw(encode_utf8);
use LWP::UserAgent;
require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration   use DPP::Agent ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(

                              ) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(

            );

our $VERSION = '0.01';

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {};
    bless($self, $class);
    my $cfg = { @_ };
    $self->{'cfg'} = $cfg;
    if (!defined $self->{'cfg'}{'url'}) {
        croak "Need at least url!"
    }
    $self->{'bootstrap'} = $self->download_bootstrap;
    $self->bootstrap;

    return $self;
}

sub download_bootstrap {
    my $self = shift;
    my $ua = LWP::UserAgent->new;
    $ua->timeout(10);
    $ua->env_proxy;

    my $response = $ua->get($self->{'cfg'}{'url'});

    if ($response->is_success) {
        $log->notice("Downloaded bootstap file");
        my $bs_hash = sha256_hex(encode_utf8($response->decoded_content));
        if ( defined($self->{'cfg'}{'checksum'})) {
            if ($bs_hash  ne lc($self->{'cfg'}{'checksum'})) {
                croak("Hash checksum mismatch! got $bs_hash, expected " . $self->{'cfg'}{'checksum'});
            }
            else {
                $log->notice("checksum correct")
            }
        }
        return $response->decoded_content;
    }
    else {
        croak "Failed on downlaoding bootstrap: " . $response->status_line; ;
    }
    return;
}
sub bootstrap {
    my $self = shift;
    $log->notice("starting bootstrap");
    my $bs = Load($self->{'bootstrap'});
    $log->notice("Setting umask to 077");
    umask 077;
    if ($bs->{'dpp-config'}) {
        $log->notice('writing DPP config');
        write_file('/etc/dpp.conf', $bs->{'dpp-config'});
    }
    if ($bs->{'hiera-config'}) {
        $log->notice('writing DPP config');
        write_file('/etc/puppet/hiera.yaml', $bs->{'hiera-config'});
    }
    if ($bs->{'puppet-config'}) {
        $log->notice('writing DPP config');
        write_file('/etc/puppet/puppet.conf', $bs->{'puppet-config'});
    }
    if (defined($bs->{'gpg-keys'})) {
        $log->notice('importing gpg keys');
        while (my ($k, $v) = each( %{ $bs->{'gpg-keys'} } )) {
            $log->notice("importing $k");
            $|=1;
            my $pid = open(my $gpg, '|-', 'gpg', '--import');
            print $gpg $v;
            close $gpg;
            waitpid $pid, 0;
        }
    }
        return;
}


1;
