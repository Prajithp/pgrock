package Proxy::Server::Connection;
use Mojo::Base 'Mojo::EventEmitter';

use Mojo::IOLoop;

has [qw/server stream id vhost/];

has clients => sub { +{} };

sub new {
    my $self = shift->SUPER::new(@_);

    my $domain = $self->domain_alias . '.local.net';
    $self->stream->write("Your Domain name $domain");

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