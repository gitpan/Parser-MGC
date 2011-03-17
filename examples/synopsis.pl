use strict;
use warnings;

package LispParser;
use base qw( Parser::MGC );

use constant pattern_ident => qr{[[:alnum:]+*/._:-]+};

sub parse
{
   my $self = shift;

   $self->sequence_of( sub {
      $self->any_of(
         sub { $self->token_int },
         sub { $self->token_string },
         sub { \$self->token_ident },
         sub { $self->scope_of( "(", \&parse, ")" ) }
      );
   } );
}

my $parser = LispParser->new;

use Data::Dump qw( pp );

if( !caller ) {
   print pp( $parser->from_file( $ARGV[0] ) );
}

1;
