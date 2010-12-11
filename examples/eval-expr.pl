#!/usr/bin/perl

use strict;
use warnings;

use base qw( Parser::MGC );

sub parse
{
   my $self = shift;

   $self->parse_term;
}

sub parse_term
{
   my $self = shift;

   my $lhs = $self->parse_factor;

   $self->one_of(
      sub { $self->expect( "+" ); $self->commit; $lhs + $self->parse_term },
      sub { $self->expect( "-" ); $self->commit; $lhs - $self->parse_term },
      sub { $lhs }
   );
}

sub parse_factor
{
   my $self = shift;

   my $lhs = $self->parse_atom;

   $self->one_of(
      sub { $self->expect( "*" ); $self->commit; $lhs * $self->parse_term },
      sub { $self->expect( "/" ); $self->commit; $lhs / $self->parse_term },
      sub { $lhs }
   );
}

sub parse_atom
{
   my $self = shift;

   $self->one_of(
      sub { $self->scope_of( "(", sub { $self->commit; $self->parse }, ")" ) },
      sub { $self->token_int },
   );
}

use Data::Dump qw( pp );

my $parser = __PACKAGE__->new;

while( defined( my $line = <STDIN> ) ) {
   my $ret = eval { $parser->from_string( $line ) };
   print $@ and next if $@;

   print pp( $ret ) . "\n";
}
