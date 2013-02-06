package DPP::Manager::Report;
use common::sense;
use Mojo::Base 'Mojolicious::Controller';
use JSON::XS;
use YAML::XS;
sub post_report {
    my $self = shift;
    if(defined ($self->req->json) ) {
        open(F,'>','/tmp/report.' . time() );
        print F Dump $self->req->json;
        $self->render( json =>  {msg => "OK"} );
        close(F);
        $self->app->{'db'}->add_report($self->req->json);
    }
    else {
        $self->render( text => "no valid report in body" );
    }
};


sub get_summary {
    my $self = shift;
    my $data = $self->app->{'db'}->get_report_summary();
    my $report = [];
    foreach my $host (@$data) {
        my $row = [];
        push @$row, $host->{'hostname'};
        push @$row, $host->{'last_run'};
        push @$row, $host->{'resource_changed'} . '/' . $host->{'resource_failed'} . '/' . $host->{'resource_total'};
        push @$row, $host->{'config_retrieval_time'};
        push @$row, $host->{'total_time'};
        push @$row, $host->{'config_version'};
        push @$report, $row;
    }
    print "ready\n";
    $self->respond_to(
        json => {json => {aaData => $report}},
        txt  => {template => 'index'},
        html => {template => 'index'},
    );
}


1;
