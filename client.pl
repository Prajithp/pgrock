#!/usr/bin/env perl

use feature 'say';

use Mojo::IOLoop;
use Mojo::Message::Request;


my $local_port = $ARGV[0] or die "Usage $0 <PORT>";

my $id = Mojo::IOLoop->client({port => 1080} => sub { 
    my ($loop, $err, $c_stream) = @_;
        $c_stream->timeout(0);

        $c_stream->on(read => sub  {
            my ($http_stream, $bytes) = @_;

            my $req = Mojo::Message::Request->new;
            $req->parse($bytes);

            if ($req->headers->host) {
                my $http_server = Mojo::IOLoop->client({port => $local_port} => sub { 
                    my ($loop, $err, $stream) = @_;
                    
                    $stream->on('read' => sub {
                        my ($stream, $bytes) = @_;
                        $http_stream->write($bytes);
                    }) if $stream;
                    
                   $stream->write($bytes) if !$err;
                });

                say sprintf("%s -> %s -> %s", $req->method, $req->url, $req->body);
            }
            else {
                say $bytes;
            }
        });
});

Mojo::IOLoop->start unless Mojo::IOLoop->is_running;
