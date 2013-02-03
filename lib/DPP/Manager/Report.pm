package DPP::Manager::Report;
use common::sense;
use Mojo::Base 'Mojolicious::Controller';
use JSON::XS;
use YAML::XS;
sub report {
    my $self = shift;
    if(defined ($self->req->json) ) {
        open(F,'>','/tmp/report.' . time() );
        print F Dump $self->req->json;
        $self->render( json =>  {msg => "OK"} );
        close(F);
    }
    else {
        $self->render( text => "!" );
    }

};

1;
