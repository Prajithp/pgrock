package Proxy::Server;
use Mojo::Base -base;

use Mojo::IOLoop;

use Proxy::Server::Connection;
use Proxy::Server::HTTP;

has address => '0.0.0.0';
has port => '1080';
has http_port => '8080';

sub start {
    my $self = shift;

    my $http_server = $self->listen_http();

    my $server = Mojo::IOLoop->server({address => $self->address, port => $self->port}, sub {
        my ($loop, $stream, $id) = @_;
        $stream->timeout(0);
        Proxy::Server::Connection->new(
            server => $self, 
            stream => $stream, 
            id => $id,
            vhost => $http_server
        );
    });
    say sprintf("Server started on tcp://%s:%s", $self->address, $self->port);
    Mojo::IOLoop->start unless Mojo::IOLoop->is_running;
}

sub listen_http {
    my $self = shift;

    my $http = Proxy::Server::HTTP->new(
        port => $self->http_port
    );
    return $http;
}

1;