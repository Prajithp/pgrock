package Pgrock::Server::Registry;

use Mojo::Base -base;
use feature qw < postderef >;
use Data::Dumper;

has clients => sub { +{} };
has hosts   => sub { +{} };

sub add_client {
    my ($self, $identifier, $client) = @_;

    $self->clients->{$identifier} = $client;
    return $self;
}

sub get_client {
    my ($self, $identifier) = @_;

    return $self->clients->{$identifier};
}

sub add_http {
    my ($self, $id, $http) = @_;
    $self->hosts->{$id} = $http;

    return $self;
}

sub get_http {
    my ($self, $id) = @_;

    return $self->hosts->{$id};
}

sub get_http_by_client_id {
    my ($self, $id) = @_;
    my $clients = [ grep { $_->tunnel_id eq $id } values $self->hosts->%* ];
    return (scalar $clients->@* > 0) ? $clients->[0] : undef;
}

sub get_identifier_by_id {
    my ($self, $id) = @_;

    my $clients = [ grep { $_->id eq $id } values $self->clients->%* ];
    return (scalar $clients->@* > 0) ? $clients->[0] : undef;
}   

sub get_http_by_identifier {
    my ($self, $identifier) = @_;

    my $clients = [ grep { $_->identifier eq $identifier } values $self->hosts->%* ];
    return $clients;
}

sub remove_http {
    my ($self, $id) = @_;

    return delete $self->hosts->{$id}
        if exists $self->hosts->{$id};
}

sub remove_client {
    my ($self, $identifier) = @_;
    return delete $self->clients->{$identifier}
        if exists $self->clients->{$identifier};
}

1;