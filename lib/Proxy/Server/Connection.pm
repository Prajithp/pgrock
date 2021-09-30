package Proxy::Server::Connection;
use Mojo::Base -base;

use Mojo::IOLoop;

has [qw/server stream id vhost/];

has domain => 'local.net';

sub new {
    my $self = shift->SUPER::new(@_);

    my $domain = sprintf("%s.%s", $self->domain_alias(), $self->domain);
    $self->stream->write("Your Domain name $domain");
    
    my $handler = $self->stream->handle;
    say sprintf("Client connected (%s:%s)", $handler->peerhost, $handler->peerport);

    $self->stream->on('close' => sub {
        $self->vhost->remove($domain);
        say sprintf("Client %s removed", $domain);
    });

    $self->vhost->add($domain, $self->id);
    return $self;
}

sub domain_alias {
    my $self = shift;

    my @charset = ('A'..'Z', 'a'..'z');
    my $name = join '', @charset[map {int rand @charset} (1..8)];
    return lc $name;
}

1;