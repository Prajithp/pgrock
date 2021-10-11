package Pgrock::Server;

use Mojo::Base -base;
use Mojo::Log;
use Mojo::IOLoop;
use Data::Dumper;

use Pgrock::Message;
use Pgrock::Server::HTTP;
use Pgrock::Server::Tunnel;

use Pgrock::Server::Registry;
use Pgrock::Server::Registry::Tunnel;
use Pgrock::Server::Registry::HTTP;

has 'hub'         => sub { Pgrock::Server::Registry->new; };
has 'logger'      => sub { Mojo::Log->new; };

has 'tunnel_addr' => '0.0.0.0';
has 'tunnel_port' => 1080;
has 'http_addr'   => '0.0.0.0';
has 'http_port'   => 8080;

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
        logger  => $self->logger,
        hub     => $self->hub
    );

    $tunnel->on(
        'close' => sub {
            my ( $tunnel, $id ) = @_;

            my $http_regisry = $self->hub->get_http_by_client_id($id);
            if ( ref $http_regisry ) {
                Mojo::IOLoop->remove($id);
                $http_regisry->remove();
                $self->hub->remove_http($id);

                $self->logger->debug("Removed client from http registry");
                return;
            }

            my $tunnel_registry = $self->hub->get_identifier_by_id($id);
            if ( ref $tunnel_registry ) {
                my $identifier = $tunnel_registry->identifier;
                $tunnel_registry->remove();
                $self->hub->remove_client($identifier);

                my $clients = $self->hub->get_http_by_identifier($identifier);
                foreach my $http ( $clients->@* ) {
                    $http->remove();
                    $self->hub->remove_http( $http->id );
                    $self->logger->debug("Removed client from http registry");
                }
                $self->logger->debug("Removed client from tunnel registry");
            }
        }
    );

    $tunnel->on(
        'accept' => sub {
            my ( $tunnel, $stream, $id ) = @_;
            my $socket    = $stream->handle;
            my $peer_port = $socket->peerport;
            my $peer_addr = $socket->peerhost;
            $self->logger->debug(
                "New connection from - $id ($peer_addr:$peer_port)");
        }
    );

    $tunnel->on(
        'accept_proxy' => sub {
            my ( $tunnel, $stream, $id, $client_id ) = @_;

            my $http_regisry = $self->hub->get_http($id);
            $http_regisry->stream_id( Mojo::IOLoop->stream($stream) );
            $http_regisry->tunnel_id($client_id);

            $http_server->emit( 'proxy_established', $id );
        }
    );

    $tunnel->on(
        'init' => sub {
            my ( $tunnel, $stream, $id, $chunks ) = @_;

            my $identifier = Pgrock::Server::Utils::random_name();
            my $manager    = Pgrock::Server::Registry::Tunnel->new(
                identifier => $identifier,
                id         => $id
            );

            $self->hub->add_client( $identifier, $manager );

            my $vhost = sprintf( '%s://%s.%s',
                $self->schema, $identifier, $self->domain );

            my $message = Pgrock::Message->new(
                type  => 'init',
                bytes => $vhost
            );
            $stream->write( $message->to_json );

        }
    );

    $tunnel->on(
        'forward' => sub {
            my ( $tunnel, $stream, $chunks ) = @_;

            my $id       = $chunks->{'id'};
            my $response = $chunks->{'response'};
            my $writter  = Mojo::IOLoop->stream($id);
            $writter->write($response) if $writter;
        }
    );

    $http_server->on(
        'connection' => sub {
            my ( $http_server, $stream, $identifier, $id ) = @_;
            my $manager    = $self->hub->get_client($identifier);
            my $manager_id = $manager->id;

            if ( my $manager_stream = Mojo::IOLoop->stream($manager_id) ) {
                my $message = Pgrock::Message->new(
                    type  => 'reqProxy',
                    bytes => $id
                );
                $manager_stream->write( $message->to_json );
            }
        }
    );

    $http_server->on(
        'proxy_established' => sub {
            my ( $http_server, $id ) = @_;

            my $http_regisry = $self->hub->get_http($id);
            my $stream_id    = $http_regisry->stream_id;

            my $proxy_stream = Mojo::IOLoop->stream($stream_id);
            my $request      = $http_regisry->request;

            $proxy_stream->write( $request->to_string )
                if $proxy_stream and $request;
        }
    );

    Mojo::IOLoop->start unless Mojo::IOLoop->is_running;
}

1;