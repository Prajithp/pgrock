package Pgrock::Server::Utils;

use feature 'state';
use Docker::Names::Random;

sub random_name {
    state $dnr = Docker::Names::Random->new();
    return 'confident_ardinghelli'; #$dnr->docker_name();
}

1;