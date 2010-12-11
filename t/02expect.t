#!/usr/bin/perl -w

use strict;

use Test::More tests => 3;

package TestParser;
use base qw( Parser::MGC );

sub parse
{
   my $self = shift;

   [ $self->expect( "hello" ), $self->expect( qr/world/ ) ];
}

package main;

my $parser = TestParser->new;

is_deeply( $parser->from_string( "hello world" ),
   [ "hello", "world" ],
   '"hello world"' );

ok( !eval { $parser->from_string( "goodbye world" ) }, '"goodbye world" fails' );
is( $@,
   qq[Expected (?-xism:hello) on line 1 at:\n] . 
   qq[goodbye world\n] . 
   qq[^\n],
   'Exception from "goodbye world" failure' );
