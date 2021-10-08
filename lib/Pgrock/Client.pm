package Pgrock::Client;

use Mojo::Base -base;
use Mojo::IOLoop;
use Mojo::IOLoop::Stream;
use Mojo::Message::Response;
use Mojo::Message::Request;
use Mojo::Log;
use Pgrock::Message;
use Pgrock::Client::Proxy;
use Pgrock::Client::Forward;

has [qw< server_addr server_port local_port identifier>];
has 'logger' => sub { Mojo::Log->new; };

sub run {
    my $self = shift;

    my $client = Mojo::IOLoop->client(address => $self->server_addr, port => $self->server_port, sub {
            my ($loop, $error, $stream) =  @_;
            $stream->timeout(0);
            
            $stream->on('read' => sub {
                my ($stream, $bytes) = @_;

                my $message = Pgrock::Message->parse($bytes);
                if ($message->type eq 'init') {
                    $self->{'identifier'} = $message->bytes;
                    return $self->banner($message);
                }
                elsif ($message->type eq 'reqProxy') {
                    my $proxy = Pgrock::Client::Proxy->new(
                        server_addr => $self->server_addr,
                        server_port => $self->server_port,
                        identifier  => $message->bytes,
                        local_port  => $self->local_port
                    );
                }
            });
            my $message = Pgrock::Message->new(
                type => 'init', bytes => 'auth'
            );
            $stream->write($message->to_json);
        }
    );
    Mojo::IOLoop->start unless Mojo::IOLoop->is_running;
}

sub banner {
    my ($self, $message) = @_;
    say $message->bytes;
}

1;