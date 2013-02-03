package DPP::Manager;
use Mojo::Base 'Mojolicious';
use YAML::XS;
use File::Slurp;
use Carp qw(croak carp cluck confess);
use DPP::DB;

# This method will run once at server start
sub startup {
    my $self = shift;
    my $cfg;
    if ( -e $self->home->rel_file('cfg/config.yaml') ) {
        $cfg = read_file($self->home->rel_file('cfg/config.yaml')) || croak($!);
    } else {
        print "####################\n";
        print "WARNING! Running on default config!\n";
        print "please go to cfg/ and cp config.default.yaml to config.yaml!\n";
        print "####################\n";

        $cfg = read_file($self->home->rel_file('cfg/config.default.yaml')) || croak($!);
    }
    $cfg = Load($cfg) or croak("Config invalid: $!");
    # set defaults
        $self->plugin(
        tt_renderer => {
            template_options => {
                INCLUDE_PATH => $self->home->rel_file('templates'),
                COMPILE_DIR => $self->home->rel_file('tmp/tt_cache'),
                COMPILE_EXT => '.ttc',
                EVAL_PERL => 0,
                CACHE_SIZE =>0, # 0 means no cache
                # STAT_TTL => 3600,
            }
        }
    );
    $self->renderer->default_handler('tt');
    $self->defaults(
        title => "DPP manager",
        layout => $cfg->{'default_layout'} // 'main',
    );
    $self->plugin(PoweredBy => (name => "DPP"));
    # TODO /dev/urandom!!!
    $self->secret( $cfg->{'secret'} || rand(1000000000000000) );
    # Router
    my $r = $self->routes;

    # connect to DB
    $self->{'db'} = DPP::DB->new($cfg->{'db'});

    $self->app->config($cfg);

    # Normal route to controller
    $r->get('/' => sub {
                my $self = shift;
                $self->render(text => "work");
            });
    $r->any('/report')->to('report#post_report');
    $r->any('/status')->to('report#get_summary');
}

1;
