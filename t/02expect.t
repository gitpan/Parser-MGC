#!/usr/bin/perl -w

use strict;

use Test::More tests => 5;

package TestParser;
use base qw( Parser::MGC );

sub parse
{
   my $self = shift;

   [ $self->expect( "hello" ), $self->expect( qr/world/ ) ];
}

package HexParser;
use base qw( Parser::MGC );

sub parse
{
   my $self = shift;

   return hex +( $self->expect( qr/0x([0-9A-F]+)/i ) )[1];
}

package main;

my $parser = TestParser->new;

is_deeply( $parser->from_string( "hello world" ),
   [ "hello", "world" ],
   '"hello world"' );

is_deeply( $parser->from_string( "  hello world  " ),
   [ "hello", "world" ],
   '"  hello world  "' );

# Perl 5.13.6 changed the regexp form
# Accept both old and new-style stringification
my $modifiers = (qr/foobar/ =~ /\Q(?^/) ? '^' : '-xism';

ok( !eval { $parser->from_string( "goodbye world" ) }, '"goodbye world" fails' );
is( $@,
   qq[Expected (?$modifiers:hello) on line 1 at:\n] . 
   qq[goodbye world\n] . 
   qq[^\n],
   'Exception from "goodbye world" failure' );

$parser = HexParser->new;

is( $parser->from_string( "0x123" ), 0x123, "Hex parser captures substring" );
