#!/usr/bin/perl -w

use strict;

use Test::More tests => 7;

package TestParser;
use base qw( Parser::MGC );

sub parse
{
   my $self = shift;

   return $self->token_string;
}

package main;

my $parser = TestParser->new;

is( $parser->from_string( q['single'] ), "single", 'Single quoted string' );
is( $parser->from_string( q["double"] ), "double", 'Double quoted string' );

is( $parser->from_string( q["foo 'bar'"] ), "foo 'bar'", 'Double quoted string containing single substr' );
is( $parser->from_string( q['foo "bar"'] ), 'foo "bar"', 'Single quoted string containing double substr' );

$parser = TestParser->new(
   patterns => { string_delim => qr/"/ }
);

is( $parser->from_string( q["double"] ), "double", 'Double quoted string still passes' );
ok( !eval { $parser->from_string( q['single'] ) }, 'Single quoted string now fails' );

no warnings 'redefine';
local *TestParser::parse = sub {
   my $self = shift;
   return [ $self->token_string, $self->token_string ];
};

is_deeply( $parser->from_string( q["foo" "bar"] ),
           [ "foo", "bar" ],
           'String-matching pattern is non-greedy' );
