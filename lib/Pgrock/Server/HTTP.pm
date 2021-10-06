package Pgrock::Server::HTTP;

use Mojo::Base 'Mojo::EventEmitter';
use Mojo::Server::Daemon;


has 'port'    => '8080';
has 'address' => '0.0.0.0';
has [qw< hub logger >];

has server => sub {
    my $self = shift;

    my $listen = sprintf('http://%s:%s', $self->address, $self->port);
    return Mojo::Server::Daemon->new(
        listen => [$listen],
    );
};

sub new {
    my $self = shift->SUPER::new(@_);

    $self->server->unsubscribe('request')->on(request => sub {
        my ($daemon, $tx) = @_;

        if (my $vhost = $tx->req->headers->host) {;
            my $identifier = (split /\./, $vhost)[0] ;
            return $self->fail($tx) unless $identifier;

            $self->emit('proxy', $identifier, $tx);
        }
        else {
            return $self->fail($tx);
        }
    });
    return $self;
}

sub fail {
    my ($self, $tx) = @_;

    $tx->res->code(404);
    $tx->res->headers->content_type('text/plain');
    $tx->res->body("Not found");
    $tx->resume;
}

sub run {
  my $self = shift;

  my $loop = $self->server->ioloop;
  my $int  = $loop->recurring(1 => sub { });
  local $SIG{INT} = local $SIG{TERM} = sub { $loop->stop };
  $self->server->start->ioloop->start;
  $loop->remove($int);
}

1;