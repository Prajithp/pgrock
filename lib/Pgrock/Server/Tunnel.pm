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

        my $identifier = Pgrock::Server::Utils::random_name();
        $self->hub->add($identifier, $id);

        $stream->on('close' => sub {
            $self->hub->remove($identifier, $id); 
            $self->logger->info("Client closed the connection");  
        });
        
        $self->emit('accept', $stream, $identifier);
    });
    return $self;
}

1;