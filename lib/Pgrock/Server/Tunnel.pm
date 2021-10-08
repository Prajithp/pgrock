package Pgrock::Server::Tunnel;

use Mojo::Base 'Mojo::EventEmitter';

use Pgrock::Server::Utils;
use Pgrock::Message;

has 'port'    => '1080';
has 'address' => '0.0.0.0';
has [qw<hub logger>];

sub new {
    my $self = shift->SUPER::new(@_);

    my $server = Mojo::IOLoop->server({address => $self->address, port => $self->port}, sub {
        my ($loop, $stream, $id) = @_;
        $stream->timeout(0);

        $stream->on('close' => sub {
            $self->logger->debug("Client closed the connection - $id");
            $self->emit('close', $id);
        });

        $stream->on('read' => sub {
            my ($stream, $chunks) = @_;
            my $message = Pgrock::Message->parse($chunks);

            if ($message->type eq 'acceptProxy') {
                $self->emit('acceptProxy', $stream, $message->bytes, $id);
            }
            elsif ($message->type eq 'init') {
                $self->emit('init', $stream, $id, $message->bytes);
            }
            else {
                $self->emit('forward', $stream, $message->bytes);
            }
        });

        $self->emit('accept', $stream, $id);
    });
    say sprintf("Tunnel server running on tcp://%s:%s", $self->address, $self->port);
    return $self;
}

1;