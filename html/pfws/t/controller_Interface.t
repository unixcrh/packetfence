use strict;
use warnings;
use Test::More;


use Catalyst::Test 'pfws';
use pfws::Controller::Interface;

ok( request('/interface')->is_success, 'Request should succeed' );
done_testing();
