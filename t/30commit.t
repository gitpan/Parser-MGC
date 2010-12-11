#!/usr/bin/perl -w

use strict;

use Test::More tests => 4;

package TestParser;
use base qw( Parser::MGC );

sub parse
{
   my $self = shift;

   $self->one_of(
      sub { $self->token_int },
      sub {
         $self->scope_of( "(",
            sub {
               $self->commit;
               $self->token_string;
            },
            ")" );
      }
   );
}

package main;

my $parser = TestParser->new;

is( $parser->from_string( "123" ), 123, '"123"' );
is( $parser->from_string( '("hi")' ), "hi", '("hi")' );

ok( !eval { $parser->from_string( "(456)" ) }, '"(456)" fails' );
is( $@,
   qq[Expected string delimiter on line 1 at:\n].
   qq[(456)\n].
   qq[ ^\n],
   'Exception from "(456)" failure' );
