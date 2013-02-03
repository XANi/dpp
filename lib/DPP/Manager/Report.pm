package DPP::Manager::Report;
use common::sense;
use Mojo::Base 'Mojolicious::Controller';


sub report {
    my $self = shift;
    $self->render(text => "OK");


};
1;
