use v5.10.0;
use lib 't/lib';
use strict;
use warnings;
use Hailo::Test;
use Test::More tests => 1;

my $test = Hailo::Test->new(
    storage => "SQLite",
);
$test->test_congress_unknown;
