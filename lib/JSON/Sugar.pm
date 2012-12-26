use strict;
use warnings;
package JSON::Sugar;
# ABSTRACT: Access JSON-like data through accessor methods

use Exporter 'import';
our @EXPORT_OK = 'json_sugar';

use Carp ();
use Scalar::Util ();

our %Boolean = map { $_ => 1 } qw/
    JSON::Boolean
    Mojo::JSON::_Bool
/;

sub json_sugar ($)
{
    my $json = shift;

    Carp::croak 'invalid data'
        unless defined $json && ref($json) =~ /^(?:ARRAY|HASH)$/s;

    if (ref($json) eq 'HASH') {
        bless \$json, 'JSON::Sugar::HASH'
    } else {
        tie my @arr, 'JSON::Sugar::ARRAY', $json;
        \@arr
    }
}

sub _wrap ($)
{
    return unless defined wantarray;

    my $type = ref $_[0];
    if (!$type || exists $JSON::Sugar::Boolean{$type}) {
        print "TIE\n";
        tie my $v,
            'JSON::Sugar::Scalar',
            \$_[0];  # Use the original ref
        return $v
    }
    print "REF: $type\n";

    # HASH: copy the ref, and bless it
    return bless \(my $ref = $_[0]), 'JSON::Sugar::HASH' if $type eq 'HASH';

    # ARRAY
    tie my @arr, 'JSON::Sugar::ARRAY', $_[0];
    \@arr
}

package JSON::Sugar::New;

use overload
    '@{}' => sub { tie my @arr, 'JSON::Sugar::New::ARRAY', $_[0]; \@arr },
    '%{}' => 'FETCH',
;

sub DESTROY {}

sub TIESCALAR
{
    my ($class, $self) = @_;
    bless $self, $class
}

sub STORE
{
    # Build the upper level
    my $upper = $_[0]->[0];
    if (Scalar::Util::blessed($upper)) {
        return $upper->STORE($_[0]->[1], $_[1]);
    } elsif (ref($upper) eq 'HASH') {
        $upper->{ $_[0]->[1] } = $_[1];
    } elsif (ref($upper) eq 'ARRAY') {
        $upper->[ $_[0]->[1] ] = $_[1];
    }

    ${ $_[0]->[0] } = $_[1];
}

sub FETCH
{
    my $upper = $_[0]->[0];
    #if (Scalar::Util::blessed($upper)) {
    #    Carp::croak "value ".$upper->[1]." doesn't yet exist"
    #} else {
        Carp::croak "value doesn't yet exist"
    #}
}

# The virtual value is used as a HASH, so we return a virtual HASH
sub AUTOLOAD
{
    my $self = shift;
    our $AUTOLOAD;
    my $prop = substr($AUTOLOAD, 1+rindex($AUTOLOAD, ':'));

    if (@_ == 1) {
        return $self->STORE({ $prop => $_[0] })
    }

    return bless [ $self, $prop ], 'JSON::Sugar::New';
}

package JSON::Sugar::New::ARRAY;

sub TIEARRAY
{
    bless \(my $upper = $_[1]), $_[0]
}

sub STORE
{
    my $upper = ${$_[0]};
    ${$_[0]}->STORE(my $arr = []);
    $arr->[ $_[1] ] = $_[2];
}

sub FETCH
{
    my ($self, $index) = @_;
    bless [ ${$self}, $index ], JSON::Sugar::New::;
}

sub FETCHSIZE
{
    Carp::croak(q{the array doesn't yet exist});
}

package JSON::Sugar::HASH;

use overload
    '%{}' => sub { ${$_[0]} },
;

sub DESTROY {}

sub AUTOLOAD
{
    my $hash = ${$_[0]};
    #Test::More::note Test::More::explain $hash;
    our $AUTOLOAD;
    my $prop = substr($AUTOLOAD, 1+rindex($AUTOLOAD, ':'));
    print "XXX\n";
    if (@_ > 1) {
        print "STORE property $prop\n";
        $hash->{$prop} = $_[1];
        return unless defined wantarray;
    } elsif (!exists $hash->{$prop}) {
        tie my $v,
            'JSON::Sugar::New',
            [ $hash, $prop ];
        return $v
    }
    JSON::Sugar::_wrap($hash->{$prop});
}

package JSON::Sugar::ARRAY;

sub TIEARRAY
{
    my ($class, $arr) = @_;
    print "TIEARRAY\n";
    bless \$arr, $class
}

sub FETCH
{
    my ($arr, $index) = (${$_[0]}, $_[1]);

    if ($index <= $#$arr) {
        JSON::Sugar::_wrap($arr->[ $index ])
    } else {
        tie my $v,
            'JSON::Sugar::New',
            [ $arr, $index ];
        return $v
    }
}

sub STORE
{
    ${ $_[0] }->[ $_[1] ] = $_[2]
}

sub FETCHSIZE
{
    scalar @{ ${ $_[0] } }
}

sub STORESIZE
{
    $#{ $_[0] } = $_[1] - 1;
}

sub DESTROY {}

package Toto;

# Obsolete
sub AUTOLOAD
{
    my $arr = ${$_[0]};
    our $AUTOLOAD;
    my $index = substr($AUTOLOAD, 1+rindex($AUTOLOAD, ':'));
    Carp::croak q{can't get/set a named property on an ARRAY}
        unless $index =~ /^(?:[1-9][0-9]*|0)\z/;
    if (@_ > 1) {
        print "STORE at index $index\n";
        $arr->[$index] = $_[1];
        return unless defined wantarray;
    } elsif ($index > $#{$arr}) {
        tie my $v,
            __PACKAGE__.'::New',
            [ $arr, $index ];
        return $v
    }
    my $type = ref $arr->[$index];
    if (!$type || $type =~ /Bool/) { # JSON::Boolean, Mojo::JSON::_Bool...
        tie my $v,
            'JSON::Sugar::Scalar',
            \($arr->[$index]);
        return $v
    }
    # HASH or ARRAY
    return bless \\($arr->[$index]), 'JSON::Sugar::'.$type
}




package JSON::Sugar::Scalar;

use overload
    # Replace the value with an empty value of the requested type
    # and return the new value
    '@{}' => sub { ${$_[0]} = [] },
    '%{}' => sub { ${$_[0]} = {} },
;

sub TIESCALAR
{
    my ($class, $storage) = @_;
    print "TIESCALAR ${$storage}\n";
    bless \$storage, $class
}

sub STORE
{
    my ($self, $value) = @_;
    print "STORE $value\n";
    ${${$self}} = $value;
}

sub FETCH
{
    my ($self) = @_;
    print "FETCH\n";
    return ${${$self}}
}

sub DESTROY {}

sub AUTOLOAD
{
    my $self = shift;
    our $AUTOLOAD;
    print "$AUTOLOAD\n";
    my $prop = substr($AUTOLOAD, 1+rindex($AUTOLOAD, ':'));
    if ($prop =~ /^(?:[1-9][0-9]*|0)\z/) { # Array index?
        ${${$self}} = my $a = [];
        tie my @arr, 'JSON::Sugar::ARRAY', $a;
        return \@arr
    } else {
        ${${$self}} = my $h = {};
        return bless \$h, 'JSON::Sugar::HASH'
    }
}

1;
__END__
# vim:set et sts=4 sw=4:
