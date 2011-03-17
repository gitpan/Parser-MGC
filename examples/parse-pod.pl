#!/usr/bin/perl

use strict;
use warnings;

package PodParser;
use base qw( Parser::MGC );

sub parse
{
   my $self = shift;

   $self->sequence_of(
      sub { $self->any_of(

         sub { my $tag = $self->expect( qr/[A-Z](?=<)/ );
               $self->commit;
               my $delim = $self->expect( qr/<+/ );
               +{ $tag => $self->scope_of( undef, \&parse, ">" x length $delim ) }; },

         sub { $self->substring_before( qr/[A-Z]</ ) },
      ) },
   );
}

use Data::Dump qw( pp );

if( !caller ) {
   my $parser = __PACKAGE__->new;

   while( defined( my $line = <STDIN> ) ) {
      my $ret = eval { $parser->from_string( $line ) };
      print $@ and next if $@;

      print pp( $ret ) . "\n";
   }
}

1;
