#!/usr/bin/perl -w

use strict;

use Test::More tests => 2;

package TestParser;
use base qw( Parser::MGC );

sub parse
{
   my $self = shift;

   $self->sequence_of( sub {
      return $self->token_int;
   } );
}

package main;

my $parser = TestParser->new;

is_deeply( $parser->from_string( "123" ), [ 123 ], '"123"' );
is_deeply( $parser->from_string( "4 5 6" ), [ 4, 5, 6 ], '"4 5 6"' );
