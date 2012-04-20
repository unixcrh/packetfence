use strict;
use warnings;
use Test::More;

BEGIN { use_ok 'Catalyst::Test', 'pfws' }
BEGIN { use_ok 'pfws::Controller::Switch' }

ok( request('/switches')->is_success, 'Request should succeed' );
done_testing();
