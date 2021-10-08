package Pgrock::Server::HTTP;

use Mojo::Base 'Mojo::EventEmitter';
use Mojo::IOLoop;
use Mojo::Message::Request;
use Mojo::Message::Response;

has 'port'    => '8080';
has 'address' => '0.0.0.0';
has [qw< hub logger >];

has connections => sub { +{} };

sub new {
    my $self = shift->SUPER::new(@_);

        my $id = Mojo::IOLoop->server({port => $self->port} => sub {
            my ($loop, $stream, $id) = @_;
            $self->connections->{$id}->{'request'} = Mojo::Message::Request->new; 
            
            $stream->on('read' => sub {
                my ($stream, $bytes) = @_;
                my $request = $self->connections->{$id}->{'request'};
                $request->parse($bytes);
                
                if ($request->is_handshake) {
                    $stream->timeout(300);
                    my $proxy_id = $self->connections->{$id}->{'proxy_stream'};
                    if ($proxy_id) {
                        Mojo::IOLoop->stream($proxy_id)->write($bytes);
                        return; 
                    }
                }
                
                if ($request->is_finished) {
                    if ( my $vhost = $request->headers->host ) {
                        my $identifier = (split /\./, $vhost)[0];
                        return $self->fail($stream) if !$identifier;
                        my $manager_id = $self->hub->get($identifier);
                        return $self->fail($stream) if !$manager_id;
                        $self->connections->{$id}->{'identifier'} = $identifier;
                        $self->emit('connection', $stream, $identifier, $id);
                    }
                    else { 
                        return $self->fail($stream); 
                    }
                }
            });
            $stream->on(close => sub { 
                my $proxy_id = $self->connections->{$id}->{'proxy_stream'};
                Mojo::IOLoop->remove($proxy_id) if $proxy_id;
                delete $self->connections->{$id};
            });
        });

        say sprintf("Webserver running on http://%s:%s",$self->address, $self->port);
    return $self;
}

sub fail {
    my ($self, $stream) = @_;

    my $response = Mojo::Message::Response->new();
    $response->code(404);
    $response->headers->content_type('text/plain');
    $response->body("Not found");
    $stream->write($response->to_string);
}

1;