#!/usr/bin/perl -w

use strict;

use Test::More tests => 6;

my @positions;

package TestParser;
use base qw( Parser::MGC );

sub parse
{
   my $self = shift;

   main::is_deeply( [ $self->where ],
      $positions[0],
      '->where before parsing' );

   $self->expect( "hello" );
   main::is_deeply( [ $self->where ],
      $positions[1],
      '->where during parsing' );

   $self->expect( qr/world/ );
   main::is_deeply( [ $self->where ],
      $positions[2],
      '->where after parsing' );

   return 1;
}

package main;

my $parser = TestParser->new;

@positions = (
   [ 1, 0, "hello world" ],
   [ 1, 5, "hello world" ],
   [ 1, 11, "hello world" ], );
$parser->from_string( "hello world" );

@positions = (
   [ 1, 0, "hello" ],
   [ 1, 5, "hello" ],
   [ 2, 5, "world" ], );
$parser->from_string( "hello\nworld" );
