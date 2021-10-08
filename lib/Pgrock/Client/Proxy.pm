package Pgrock::Client::Proxy;

use Mojo::Base 'Mojo::EventEmitter';
use Mojo::IOLoop;
use Pgrock::Message;
use Mojo::Message::Response;

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

            my $message = Pgrock::Message->new(
                type => 'acceptProxy', bytes => $self->identifier
            );
            $stream->write($message->to_json);
            
            $forwarder->on('error' => sub {
                my $forwarder = shift;

                my $response = Mojo::Message::Response->new();
                $response->code(503);
                $response->headers->content_type('text/plain');
                $response->body("Timeout");
                my $meta = {'id' => $self->identifier, response => $response->to_string};
                my $message = Pgrock::Message->new(
                    type => 'proxy', bytes => $meta
                );  
                $stream->write($message->to_json) unless $stream->is_writing;
            });

            $stream->on('close' => sub {
               $self->logger->warn('Proxy closed the connection');
                my $id = $forwarder->{'client'};
                Mojo::IOLoop->remove($id) if $id;
            });
        }
    );
    return $self;
}

1;