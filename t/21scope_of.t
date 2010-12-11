#!/usr/bin/perl -w

use strict;

use Test::More tests => 3;

package TestParser;
use base qw( Parser::MGC );

sub parse
{
   my $self = shift;

   $self->scope_of(
      "(",
      sub { return $self->token_int },
      ")"
   );
}

package main;

my $parser = TestParser->new;

is( $parser->from_string( "(123)" ), 123, '"(123)"' );

ok( !eval { $parser->from_string( "(abc)" ) }, '"(abc)"' );
ok( !eval { $parser->from_string( "456" ) }, '"456"' );
