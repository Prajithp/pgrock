package Pgrock::Server::Hub;

use Mojo::Base -base;

has 'connections' => sub { +{} };

sub add {
    my ($self, $identifier, $id) = @_;

    my $connections = $self->connections;
    $connections->{$identifier} = $id;

    return $self;
}

sub remove {
    my ($self, $identifier) = @_;

    my $connections = $self->connections;
    if ($connections->{$identifier}) {
        delete $connections->{$identifier};
    }

    return $self;
}

sub get {
    my ($self, $identifier) = @_;

    my $connections = $self->connections;
    if (my $id = $connections->{$identifier}) {
        return $id;
    }

    return undef;
}

1;