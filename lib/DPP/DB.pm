package DPP::DB;
use common::sense;
use Carp qw(croak carp cluck confess);
use Data::Dumper;
use DBI;
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
    print "Checking DB\n";
    print Dumper ($t);
    if (!defined($t)) {
        print "Creating DB\n";
        $self->{'dbh'}->do(q{
            CREATE TABLE hosts (
                hostname TEXT,
                last_run INTEGER,
                config_version TEXT,
                config_retrieval_time REAL,
                total_time REAL,
                resource_total INTEGER,
                resource_changed INTEGER,
                resource_skipped INTEGER,
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
1;
