package Pgrock::Server::Registry::Tunnel;

use Mojo::Base -base;
use Mojo::IOLoop;


has [qw< id identifier >];


sub remove {
    my $self = shift;
    Mojo::IOLoop->remove($self->id);
}

1;
