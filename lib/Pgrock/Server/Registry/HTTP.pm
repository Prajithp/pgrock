package Pgrock::Server::Registry::HTTP  ;

use Mojo::Base -base;
use Mojo::IOLoop;

has [qw< id tunnel_id identifier stream_id request>];


sub remove {
    my $self = shift;

    for my $attr (qw< id tunnel_id stream_id>) {
        Mojo::IOLoop->remove($self->$attr) if $self->$attr;
    }

    return;
}

1;