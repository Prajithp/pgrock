package Pgrock::CLI;

use Mojo::Base 'Mojolicious::Command';
use Mojo::URL;
use Mojo::Util qw(getopt);

use Pgrock::Server;
use Pgrock::Client;

has description => 'Start application in client mode or with HTTP and tcp server';
has usage       => sub { shift->extract_usage };

sub run {
    my ($self, @args) = @_;

    my $http_listen = Mojo::URL->new('http://0.0.0.0:8080');
    my $tcp_listen  = Mojo::URL->new('tcp://0.0.0.0:1080');

    die $self->usage
        unless getopt \@args,
        'm|mode=s'              => \my $mode,
        'l|http-listen=s'       => sub { $http_listen = Mojo::URL->new($_[1]) },
        't|tcp-listen=s'        => sub { $tcp_listen = Mojo::URL->new($_[1]) },
        'd|domain=s'            => \my $domain,
        's|schema=s'            => \(my $schema = 'https'),
        'r|remote-address=s'    => \my $remote_address,
        'p|port=i'              => \(my $port = 1080),
        'f|local-port=i'        => \my $local_port;

    die $self->usage unless $mode;

    if ($mode eq 'server' and $domain) {
        my $srv = Pgrock::Server->new(
            tunnel_addr  => $tcp_listen->host,
            tunnel_port  => $tcp_listen->port,
            http_addr    => $http_listen->host,
            http_port    => $http_listen->port,
            schema       => $schema,
            domain       => $domain
        );
        $srv->run;
    }
    elsif ($mode eq 'client' and $local_port and $remote_address) {
        my $client = Pgrock::Client->new(
            server_addr => $remote_address,
            server_port => $port,
            local_port  => $local_port
        );
        $client->run;
    }
    else {
        die $self->usage;
    }
}

1;


=encoding utf8

=head1 NAME

Pgrock::CLI - Pgrock commands

=head1 SYNOPSIS

  Usage: APPLICATION [OPTIONS]
    pgrock -m server -d domain -s http -l http://0.0.0.0:8080 -t tcp://0.0.0.0:1080
    pgrock -m client -f 8080 -r 192.168.0.1 -p 1080
  Options:
    -m, --mode <server|client>              Operating mode for your application,
                                            valid options are server and client
    server:
        -l, --http_listen <location>        Listen interface and port number for
                                            HTTP Server
        -t, --tcp_listen <location>         Inteface and port number for tunnel
                                            tcp listener
        -s  --schema <http|https>           Set the schema according to your
                                            web server running mode
        -d  --domain <domain name>          Custom domain name you want for routing
                                            set A record for *.<domain> to server IP
    client:
        -r  --remote_address <address>      Remote server ip address where the server
                                            is running                                    
        -p, --port <number>                 Port number of the remote server 
        -f  --local_port <number>           Forward all requests to your application
                                            running in your machine

=cut
