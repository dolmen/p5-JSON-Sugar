use strict;
use warnings;

use Test::More;

use JSON; # For JSON::true
use JSON::Sugar 'json_sugar';

my $data = [
    5,
    "Hello",
    JSON::true,
    [
	"One",
	5.2,
	JSON::false,
    ],
];

my $json = json_sugar($data);

is($json->[0], 5, 'index');

#is($json->'0'(), 5, 'index');

done_testing;
