use strict;
use warnings;

use Test::More;

use JSON; # For JSON::true
use JSON::Sugar 'json_sugar';

# The example from RFC4627
my $data = {
    Image => {
        Width =>  800,
        Height => 600,
        Title =>  "View from 15th Floor",
        Thumbnail => {
            Url =>    "http://www.example.com/image/481989943",
            Height => 125,
            Width =>  "100",   # This inconsistency is in the RFC
        },
        IDs => [ 116, 943, 234, 38793 ],
    }
};


my $json = json_sugar($data);

is($json->Image->Width, 800, 'fetch prop');
$json->Image->Width(732);
is($json->Image->Width, 732, 'fetch prop');

is($json->Image->Thumbnail->Height, 125, 'fetch multi levels');

use Carp::Always;

$json->Toto(5);
$json->Lili({})->Lolo('Hello');
$json->X({})->Y({})->Z([]);
$json->X->Y->Z->[1] = 2;
($json->X->Y->Z->[2] = { a => 3 })->a(6);

#$json->Lili->{Lolo} = 'Hello';
#$json->Lili->[2] = 'Hello';

note explain $data;

done_testing;
