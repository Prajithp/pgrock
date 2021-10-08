package Pgrock::Client::Forward;

use Mojo::Base 'Mojo::EventEmitter';
use Mojo::IOLoop;
use Pgrock::Message;

has [qw< local_port stream bytes identifier>];
has 'logger' => sub { Mojo::Log->new; };

sub new {
    my $self = shift->SUPER::new(@_);

    $self->{'client'} = Mojo::IOLoop->client(port => $self->local_port, 
        sub {
            my ($loop, $err, $stream) = @_;
            $stream->timeout(300);

            $stream->on('read' => sub {
                my ($stream, $chunks) = @_;
               
                my $meta = {'id' => $self->identifier, response => $chunks};
                my $message = Pgrock::Message->new(
                    type => 'proxy', bytes => $meta
                );  
                $self->stream->write($message->to_json);
            });
            $stream->on('close' => sub {
                $self->logger->warn("Application closed the connection");
                Mojo::IOLoop->remove(Mojo::IOLoop->stream($self->stream));
            })
        }
    );
    return $self;
}

sub write {
    my $self = shift;
    my $stream = Mojo::IOLoop->stream($self->{'client'});
    $stream->write(pop) if $stream;
}

1;