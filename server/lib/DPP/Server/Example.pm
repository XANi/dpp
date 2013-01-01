package DPP::Server::Example;
use Mojo::Base 'Mojolicious::Controller';

# This action will render a template
sub welcome {
  my $self = shift;
  $self->render(
      text => 'Welcome to the Mojolicious real-time web framework!',
  );
}

1;
