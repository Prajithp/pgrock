package Pgrock::Server::HTTP;

use Mojo::Base 'Mojo::EventEmitter';
use Mojo::IOLoop;
use Mojo::Message::Request;
use Mojo::Message::Response;

use Pgrock::Server::Registry;
use Pgrock::Server::Registry::HTTP;

has 'port'    => '8080';
has 'address' => '0.0.0.0';
has [qw< hub logger >];

sub new {
    my $self = shift->SUPER::new(@_);

    my $id = Mojo::IOLoop->server(
        { port => $self->port } => sub {
            my ( $loop, $stream, $id ) = @_;

            my $http_regisry = Pgrock::Server::Registry::HTTP->new(
                id      => $id,
                request => Mojo::Message::Request->new
            );

            $stream->on(
                'read' => sub {
                    my ( $stream, $bytes ) = @_;

                    my $request = $http_regisry->request;
                    $request->parse($bytes);

                    if ( $request->is_handshake ) {
                        $stream->timeout(300);
                        my $stream_id = $http_regisry->stream_id;
                        if ($stream_id) {
                            Mojo::IOLoop->stream($proxy_id)->write($bytes);
                            return;
                        }
                    }

                    if ( $request->is_finished ) {
                        if ( my $vhost = $request->headers->host ) {
                            my $identifier = ( split /\./, $vhost )[0];
                            return $self->fail($stream) if !$identifier;
                            my $manager = $self->hub->get_client($identifier);

                            return $self->fail($stream) if !$manager;
                            $http_regisry->identifier($identifier);
                            $self->hub->add_http( $id, $http_regisry );

                            $self->emit( 'connection', $stream, $identifier,
                                $id );
                        }
                        else {
                            return $self->fail($stream);
                        }
                    }
                }
            );

            $stream->on(
                close => sub {
                    my $stream_id = $http_regisry->stream_id;
                    Mojo::IOLoop->remove($stream_id) if $stream_id;
                    $self->hub->remove_http($id);
                }
            );

        }
    );

    say sprintf( "Webserver running on http://%s:%s",
        $self->address, $self->port );
    return $self;
}

sub fail {
    my ( $self, $stream ) = @_;

    my $response = Mojo::Message::Response->new();
    $response->code(404);
    $response->headers->content_type('text/plain');
    $response->body("Not found");
    $stream->write( $response->to_string );
}

1;