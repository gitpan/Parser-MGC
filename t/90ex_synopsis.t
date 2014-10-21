#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

require "examples/synopsis.pl";

my $parser = LispParser->new;

sub test
{
   my ( $str, $expect ) = @_;

   is_deeply( $parser->from_string( $str ), [ $expect ], qq("$str") );
}

test "123", 123;
test "'hello'", 'hello';
test "(123 456)", [ 123, 456 ];
test "(+ 1 (* 2 3))", [ \'+', 1, [ \'*', 2, 3 ] ];

done_testing;
