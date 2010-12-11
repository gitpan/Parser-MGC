#!/usr/bin/perl -w

use strict;

use Test::More tests => 6;

package TestParser;
use base qw( Parser::MGC );

sub parse
{
   my $self = shift;

   return $self->token_int;
}

package main;

my $parser = TestParser->new;

is( $parser->from_string( "123" ), 123, 'Decimal integer' );
is( $parser->from_string( "0" ),     0, 'Zero' );
is( $parser->from_string( "0x20" ), 32, 'Hexadecimal integer' );
is( $parser->from_string( "010" ),   8, 'Octal integer' );

is( $parser->from_string( "-4" ), -4, 'Negative decimal' );

ok( !eval { $parser->from_string( "hello" ) }, '"hello" fails' );
