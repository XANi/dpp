package DPP::Server;
use Mojo::Base 'Mojolicious';

# This method will run once at server start
sub startup {
  my $self = shift;

  # Documentation browser under "/perldoc"
  $self->plugin('PODRenderer');

  # Router
  my $r = $self->routes;

  # Normal route to controller
  $r->get('/')->to('example#welcome');
  $r->websocket('/ws' => sub {
      my $self = shift;
      Mojo::IOLoop->stream($self->tx->connection)->timeout(300);
      $self->send("HELO");
      $self->on(message => sub {
                    my ($self, $msg) = @_;
                    print "Got $msg\n";
                    $self->send("echo: $msg");
                });
  });
}

1;
