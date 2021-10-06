package Pgrock::Client;

use Mojo::Base -base;
use Mojo::IOLoop;
use Mojo::IOLoop::Stream;
use Mojo::Log;
use Pgrock::Message;

has [qw< server_addr server_port local_port>];
has 'logger' => sub { Mojo::Log->new; };

sub run {
    my $self = shift;

    my $client = Mojo::IOLoop->client(
        address => $self->server_addr, 
        port    => $self->server_port, 
        sub {
            my ($loop, $error, $stream) =  @_;
            $stream->timeout(0);

            $stream->on('read' => sub {
                my ($stream, $bytes) = @_;
                $self->handler($stream, $bytes);
            });
        }
    );
    Mojo::IOLoop->start unless Mojo::IOLoop->is_running;
}

sub handler {
    my ($self, $handler, $bytes) = @_;

    my $client = Mojo::IOLoop->client({port => $self->local_port} => sub {
        my ($loop, $error, $stream) = @_;

        $stream->on('read' => sub {
            my $message = Pgrock::Message->new(
                type => 'proxy', bytes => pop
            );
            $handler->write($message->to_json);
        });

        my $message = Pgrock::Message->new->parse($bytes);
        if ($message->type eq 'proxy') {
            $self->logger->debug("Forwarding request to application");
            $stream->write($message->bytes);
        }
        elsif ($message->type eq 'init') {
            $self->banner($message);
        }
        else {
            $self->logger->error("Invalid message from the server");
        }
    });
    return $self;
}

sub banner {
    my ($self, $message) = @_;
    say $message->bytes;
}

1;