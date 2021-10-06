package Pgrock::Message;

use Mojo::Base -base;
use Mojo::JSON qw<encode_json decode_json>;

has [qw< bytes type >];

sub parse {
    my ($self, $chunks) = @_;

    my $struct = decode_json($chunks);
    for my $attr (qw< bytes type >) {
        $self->{$attr} = $struct->{$attr} if exists $struct->{$attr};
    }
    return $self;
}

sub to_json {
    my $self = shift;

    my %struct = map { $_ => $self->$_ } qw< bytes type>;
    return encode_json(\%struct); 
}

1;