package Proxy::Server::HTTP;
use Mojo::Base 'Mojo::EventEmitter';

use Mojo::IOLoop;
use Mojo::Message::Request;
use Mojo::Message::Response;

has address => '0.0.0.0';
has port => '8080';
has clients => sub { +{} };

sub new {
    my $self = shift->SUPER::new(@_);

    my $server = Mojo::IOLoop->server({address => $self->address, port => $self->port}, sub {
        my ($loop, $stream, $id) = @_;

        $stream->on('read' => sub{
            my ($stream, $bytes) = @_;

            my $req = Mojo::Message::Request->new;
            $req->parse($bytes);
            my $vhost = $req->headers->host;
            my $stream_id = $self->clients->{$vhost};
            if (defined $stream_id) {
                Mojo::IOLoop->stream($stream_id)->write($bytes);

                Mojo::IOLoop->stream($stream_id)->on('read' => sub{
                    my ($c_stream, $chunk) = @_;
                    $stream->write($chunk);
                });
            }
            else {
                my $res = Mojo::Message::Response->new;
                $res->code(400);
                $res->headers->content_type('text/plain');
                $res->body('Not Found');
                $stream->write($res->to_string);
            }
        });
    });

    return $self;
}

sub add {
    my ($self, $domain, $id) = @_;

    my $clients = $self->clients;
    $clients->{$domain} = $id;

    return $self;
}

1;
