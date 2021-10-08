package Pgrock::Client::Proxy;

use Mojo::Base 'Mojo::EventEmitter';
use Mojo::IOLoop;
use Pgrock::Message;

has [qw< server_addr server_port local_port identifier>];
has 'logger' => sub { Mojo::Log->new; };

sub new {
    my $self = shift->SUPER::new(@_);

    $self->{'client'} = Mojo::IOLoop->client(address => $self->server_addr, port => $self->server_port, 
        sub {
            my ($loop, $err, $stream) = @_;
            $stream->timeout(300);

            my $forwarder = Pgrock::Client::Forward->new(
                local_port => $self->local_port,
                stream => $stream,
                identifier => $self->identifier,
            );

            $stream->on('read' => sub {
                my ($stream, $chunks) = @_;

                $forwarder->write($chunks);
            });

            $stream->on('close' => sub {
               $self->logger->warn('Proxy closed the connection');
                my $id = $forwarder->{'client'};
                Mojo::IOLoop->remove($id) if $id;
            });

            my $message = Pgrock::Message->new(
                type => 'acceptProxy', bytes => $self->identifier
            );
            $stream->write($message->to_json);
        }
    );
    return $self;
}

1;