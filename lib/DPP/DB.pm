package DPP::DB;
use common::sense;
use Carp qw(croak carp cluck confess);
use Data::Dumper;
use DBI;
use Log::Any qw($log);
sub new {
    my $proto = shift;
    my $cfg;
    if (ref($_[0]) eq 'HASH') {

        $cfg = shift;

    } else {
        my %c = @_;
        $cfg = \%c;
    }
    my $class = ref($proto) || $proto;
    my $self = {
        cfg => $cfg,
    };
    if ($self->{'cfg'}{'path'} !~ /sqlite/i) {
        croak("Unsupported DB type, only sqlite is supported atm");
    }
    print "DB: $self->{'cfg'}{'path'} \n";
    $self->{'dbh'} =  DBI->connect(
        $self->{'cfg'}{'path'},
        $self->{'cfg'}{'user'},
        $self->{'cfg'}{'pass'},
        { RaiseError => 1 }
    ) or croak($DBI::errst);
    bless($self, $class);
    $self->init_sqlite;
    return $self;
};
sub dbh {
    my $self = shift;
    return $self->{'dbh'};
}

sub init_sqlite {
    my $self = shift;
    my $check_config_table = $self->{'dbh'}->prepare(q{SELECT * FROM sqlite_master WHERE name = 'config'});
    $check_config_table->execute();
    my $t = $check_config_table->fetchrow_arrayref;
    if (!defined($t)) {
        $self->{'dbh'}->do(q{
            CREATE TABLE hosts (
                ts INTEGER,
                hostname TEXT,
                last_run INTEGER,
                config_version TEXT,
                config_retrieval_time REAL,
                total_time REAL,
                resource_total INTEGER,
                resource_changed INTEGER,
                resource_failed INTEGER
             )
        }) or croak("Cant create table hosts:" . $DBI::errstr);
        $self->{'dbh'}->do(q{
            CREATE TABLE config (
                key TEXT,
                val TEXT
            )
        }) or croak("Cant create table config:" . $DBI::errstr);
        $self->{'dbh'}->do(q{ INSERT INTO config(key, val) VALUES('version','0.0.1')}) or croak($DBI::errstr);;
    }
}

sub get_report_summary {
    my $self = shift;
    my $report_data = $self->{'dbh'}->prepare('SELECT * FROM hosts');
#    $report_data->execute( scalar time - (3600 * 24 * 7) );
    $report_data->execute();
    my $report = [];
    while(my $row = $report_data->fetchrow_hashref) {
        push @$report, $row;
    }
    print Dumper $report;
    return $report;
}

sub add_report {
    my $self   = shift;
    my $report = shift;
    if (   !defined( $report->{'version'}{'config'} )
        || !defined( $report->{'time'}{'config_retrieval'} )
        || !defined( $report->{'time'}{'total'} )
        || !defined( $report->{'time'}{'last_run'} )
        || !defined( $report->{'hostname'} )
        || !defined( $report->{'resources'}{'total'} )
        || !defined( $report->{'resources'}{'changed'} )
        || !defined( $report->{'resources'}{'failed'} ) )
    {
        $log->warn("Bad report received, ignoring");
        print "BAD REPORT\n";
        return
    }
    print "ADDING REPORT\n";
    my $find_host = $self->{'dbh'}->prepare(q{SELECT * FROM hosts WHERE hostname = ?});
    $find_host->execute( $report->{'hostname'} );
    my $update = $find_host->fetchrow_arrayref;
    my $query;
    if ( defined($update) ) {
        print "UPDATE REPORT\n";
        $query = $self->{'dbh'}->prepare(q{
            UPDATE hosts
            SET
                ts = ?,
                last_run = ?,
                config_version = ?,
                config_retrieval_time = ?,
                total_time = ?,
                resource_total = ?,
                resource_changed = ?,
                resource_failed = ?
            WHERE hostname = ?
        });
    }
    else {
        print "ADD REPORT\n";
        $query = $self->{'dbh'}->prepare(q{
            INSERT INTO hosts(
                ts,
                last_run,
                config_version,
                config_retrieval_time,
                total_time,
                resource_total,
                resource_changed,
                resource_failed,
                hostname)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?,?)
         })
    }
    $query->execute(
        scalar time(),
        $report->{'time'}{'last_run'},
        $report->{'version'}{'config'},
        $report->{'time'}{'config_retrieval'},
        $report->{'time'}{'total'},
        $report->{'resources'}{'total'},
        $report->{'resources'}{'changed'},
        $report->{'resources'}{'failed'},
        $report->{'hostname'}
    );
}

1;
