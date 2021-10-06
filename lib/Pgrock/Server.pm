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
        logger  => $self->logger,
        hub     => $self->hub
    );

    $tunnel->on('accept' => sub {
        my ($tunnel, $stream, $identifier) = @_;
  
        my $vhost   = sprintf('%s://%s.%s', $self->schema, $identifier, $self->domain);
        my $message = Pgrock::Message->new(type => 'init', bytes => $vhost);
        $stream->write($message->to_json);
    });

    $http_server->on('proxy', sub {
        my ($server, $identifier, $tx) = @_;
    
        my $client_id = $self->hub->get($identifier);
        if ($client_id) {
            my $message = Pgrock::Message->new(
                type  => 'proxy', 
                bytes => $tx->req->to_string
            );

            Mojo::IOLoop->stream($client_id)->write($message->to_json);
            Mojo::IOLoop->stream($client_id)->on('read' => sub {
                my ($client_stream, $bytes) = @_;
                
                my $message = Pgrock::Message->new->parse($bytes);
                $tx->res->parse($message->bytes);
                $tx->resume;
            });
        }
        else {
            $server->fail($tx);
        }
    });

    $http_server->run;
}

1;