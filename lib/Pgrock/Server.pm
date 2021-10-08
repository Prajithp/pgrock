package Pgrock::Server;

use Mojo::Base -base;
use Mojo::Log;
use Mojo::IOLoop;

use Pgrock::Message;
use Pgrock::Server::HTTP;
use Pgrock::Server::Tunnel;
use Pgrock::Server::Hub;

has 'hub'         => sub { Pgrock::Server::Hub->new; };
has 'logger'      => sub { Mojo::Log->new; };
has 'tunnel_addr' => '0.0.0.0';
has 'tunnel_port' => 1080;
has 'http_addr'   => '0.0.0.0';
has 'http_port'   => '8080';

has [qw< domain schema >];

sub run {
    my $self = shift;

    my $tunnel = Pgrock::Server::Tunnel->new(
        port    => $self->tunnel_port,
        address => $self->tunnel_addr,
        hub     => $self->hub,
        logger  => $self->logger,
    );
    my $http_server = Pgrock::Server::HTTP->new(
        port    => $self->http_port,
        address => $self->http_addr,
        lxogger  => $self->logger,
        hub     => $self->hub
    );

    $tunnel->on('close' => sub {
        my ($tunnel, $id) = @_;

        my $http_conns = $http_server->connections;

        foreach my $http_id (keys %{$http_conns}) {
            my $proxyId = $http_conns->{$http_id}->{'proxy_stream'};
            my $clientId = $http_conns->{$http_id}->{'client_id'};
            if ($proxyId && $id eq $clientId) {
                $self->logger->debug("Closing all http connection of $clientId");
                Mojo::IOLoop->remove($http_id);
                Mojo::IOLoop->remove($proxyId) if $proxyId;
                Mojo::IOLoop->remove($clientId);
                last;
            }

            my $identifier = $http_conns->{$http_id}->{'identifier'};
            if ($identifier && $self->hub->get($identifier) eq $id) {
                $self->logger->debug("Removing $identifier from registry");
                $self->hub->remove($identifier);
                my $proxyId = $http_conns->{$http_id}->{'proxyId'};
                my $clientId = $http_conns->{$http_id}->{'clientId'};
                Mojo::IOLoop->remove($proxyId) if $proxyId;
                Mojo::IOLoop->remove($clientId) if $clientId;
                Mojo::IOLoop->remove($http_id);
                last;
            } 
        }
    });

    $tunnel->on('accept' => sub {
        my ($tunnel, $stream, $id) = @_;
        my $socket = $stream->handle;
        my $peer_port = $socket->peerport;
        my $peer_addr = $socket->peerhost;
        $self->logger->debug("New connection from - $id ($peer_addr:$peer_port)");
    });

    $tunnel->on('acceptProxy' => sub {
        my ($tunnel, $stream, $id, $clientId) = @_;
        $http_server->connections->{$id}->{'proxy_stream'} = Mojo::IOLoop->stream($stream);
        $http_server->connections->{$id}->{'client_id'} = $clientId;
        $http_server->emit('proxy_established', $id);
    });

    $tunnel->on('init' => sub {    
        my ($tunnel, $stream, $id, $chunks) = @_;

        my $identifier = Pgrock::Server::Utils::random_name();
        $self->hub->add($identifier, $id);
        
        my $vhost   = sprintf('%s://%s.%s', $self->schema, $identifier, $self->domain);
        my $message = Pgrock::Message->new(type => 'init', bytes => $vhost);
        $stream->write($message->to_json);
    });

    $tunnel->on('forward' => sub {
        my ($tunnel, $stream, $chunks) = @_;
        my $id = $chunks->{'id'};
        my $response = $chunks->{'response'};
        my $writter = Mojo::IOLoop->stream($id);
        $writter->write($response) if $writter;
    });

    $http_server->on('connection' => sub {
        my ($http_server, $stream, $identifier, $id) = @_;
        my $manager_id = $self->hub->get($identifier);

        if (my $manager_stream = Mojo::IOLoop->stream($manager_id)) {
            my $message = Pgrock::Message->new(type => 'reqProxy', bytes => $id);
            $manager_stream->write($message->to_json);
        }
    });

    $http_server->on('proxy_established' => sub {
        my ($http_server, $id) = @_;
        my $proxy_stream = Mojo::IOLoop->stream(
            $http_server->connections->{$id}->{'proxy_stream'}
        );
        my $request = $http_server->connections->{$id}->{'request'};
        $proxy_stream->write($request->to_string) if $proxy_stream and $request;
    });

    Mojo::IOLoop->start unless Mojo::IOLoop->is_running;
}

1;