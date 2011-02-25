#  You may distribute under the terms of either the GNU General Public License
#  or the Artistic License (the same terms as Perl itself)
#
#  (C) Paul Evans, 2010-2011 -- leonerd@leonerd.org.uk

package Parser::MGC;

use strict;
use warnings;

our $VERSION = '0.05';

use Carp;

use File::Slurp qw( slurp );

=head1 NAME

C<Parser::MGC> - build simple recursive-descent parsers

=head1 SYNOPSIS

 package My::Grammar::Parser
 use base qw( Parser::MGC );

 sub parse
 {
    my $self = shift;

    $self->sequence_of( sub {
       $self->one_of(
          sub { $self->token_int },
          sub { $self->token_string },
          sub { \$self->token_ident },
          sub { $self->scope_of( "(", \&parse, ")" ) }
       );
    } );
 }

 my $parser = My::Grammar::Parser->new;

 my $tree = $parser->from_file( $ARGV[0] );

 ...

=head1 DESCRIPTION

This base class provides a low-level framework for building recursive-descent
parsers that consume a given input string from left to right, returning a
parse structure. It takes its name from the C<m//gc> regexps used to implement
the token parsing behaviour.

It provides a number of token-parsing methods, which each atomically extract a
grammatical token from the string. It also provides wrapping methods that can
be used to build up a possibly-recursive grammar structure. Each method, both
token and structural, atomically either consumes a prefix of the string and
returns its result, or fails and consumes nothing.

=cut

=head1 CONSTRUCTOR

=cut

=head2 $parser = Parser::MGC->new( %args )

Returns a new instance of a C<Parser::MGC> object. This must be called on a
subclass that provides a C<parse> method.

Takes the following named arguments

=over 8

=item patterns => HASH

Keys in this hash should map to quoted regexp (C<qr//>) references, to
override the default patterns used to match tokens. See C<PATTERNS> below

=item accept_0o_oct => BOOL

If true, the C<token_int> method will also accept integers with a C<0o> prefix
as octal.

=back

=cut

=head1 PATTERNS

The following pattern names are recognised. They may be passed to the
constructor in the C<patterns> hash, or provided as a class method under the
name C<pattern_I<name>>.

=over 4

=item * ws

Pattern used to skip whitespace between tokens. Defaults to C</[\s\n\t]+/>

=item * comment

Pattern used to skip comments between tokens. Undefined by default.

=item * int

Pattern used to parse an integer by C<token_int>. Defaults to
C</0x[[:xdigit:]]+|[[:digit:]]+/>. If C<accept_0o_oct> is given, then this
will be expanded to match C</0o[0-7]+/> as well.

=item * ident

Pattern used to parse an identifier by C<token_ident>. Defaults to
C</[[:alpha:]_]\w*/>

=item * string_delim

Pattern used to delimit a string by C<token_string>. Defaults to C</["']/>.

=back

=cut

my @patterns = qw(
   ws
   comment
   int
   ident
   string_delim
);

use constant {
   pattern_ws      => qr/[\s\n\t]+/,
   pattern_comment => undef,
   pattern_int     => qr/0x[[:xdigit:]]+|[[:digit:]]+/,
   pattern_ident   => qr/[[:alpha:]_]\w*/,
   pattern_string_delim => qr/["']/,
};

sub new
{
   my $class = shift;
   my %args = @_;

   $class->can( "parse" ) or
      croak "Expected to be a subclass that can ->parse";

   my $self = bless {
      patterns => {},
      scope_level => 0,
   }, $class;

   $self->{patterns}{$_} = $args{patterns}{$_} || $self->${\"pattern_$_"} for @patterns;

   if( $args{accept_0o_oct} ) {
      $self->{patterns}{int} = qr/0o[0-7]+|$self->{patterns}{int}/;
   }

   return $self;
}

=head1 METHODS

=cut

=head2 $result = $parser->from_string( $str )

Parse the given literal string and return the result from the C<parse> method.

=cut

sub from_string
{
   my $self = shift;
   my ( $str ) = @_;

   $self->{str} = $str;

   pos $self->{str} = 0;

   my $result = $self->parse;

   $self->at_eos or
      $self->fail( "Expected end of input" );

   return $result;
}

=head2 $result = $parser->from_file( $file )

Parse the given file, which may be a pathname in a string, or an opened IO
handle, and return the result from the C<parse> method.

=cut

sub from_file
{
   my $self = shift;
   my ( $filename ) = @_;

   $self->{filename} = $filename;

   $self->from_string( scalar(slurp $filename) );
}

=head2 $result = $parser->from_reader( \&reader )

Parse the input which is read by the C<reader> function. This function will be
called in scalar context to generate portions of string to parse, being passed
the C<$parser> object. The function should return C<undef> when it has no more
string to return.

 $reader->( $parser )

Note that because it is not generally possible to detect exactly when more
input may be required due to failed regexp parsing, the reader function is
only invoked during searching for skippable whitespace. This makes it suitable
for reading lines of a file in the common case where lines are considered as
skippable whitespace, or for reading lines of input interractively from a
user. It cannot be used in all cases (for example, reading fixed-size buffers
from a file) because two successive invocations may split a single token
across the buffer boundaries, and cause parse failures parse failures.

=cut

sub from_reader
{
   my $self = shift;
   my ( $reader ) = @_;

   local $self->{reader} = $reader;

   $self->{str} = "";
   pos $self->{str} = 0;

   my $result = $self->parse;

   $self->at_eos or
      $self->fail( "Expected end of input" );

   return $result;
}

=head2 ( $lineno, $col, $text ) = $parser->where

Returns the current parse position, as a line and column number, and
the entire current line of text. The first line is numbered 1, and the first
column is numbered 0.

=cut

sub where
{
   my $self = shift;

   my $pos = pos $self->{str};
   my $str = $self->{str};

   my $sol = $pos;
   $sol-- if $sol > 0 and substr( $str, $sol, 1 ) =~ m/^[\r\n]$/;
   $sol-- while $sol > 0 and substr( $str, $sol-1, 1 ) !~ m/^[\r\n]$/;

   my $eol = $pos;
   $eol++ while $eol < length($str) and substr( $str, $eol, 1 ) !~ m/^[\r\n]$/;

   my $line = substr( $str, $sol, $eol - $sol );

   my $col = $pos - $sol;
   my $lineno = ( () = substr( $str, 0, $pos ) =~ m/\n/g ) + 1;

   return ( $lineno, $col, $line );
}

=head2 $parser->fail( $message )

Aborts the current parse attempt with the given message string. The failure
message will include the current line and column position, and the line of
input that failed.

=cut

sub fail
{
   my $self = shift;
   my ( $message ) = @_;

   my ( $lineno, $col, $line ) = $self->where;

   die Parser::MGC::Failure->new( $message, $self->where );
}

=head2 $eos = $parser->at_eos

Returns true if the input string is at the end of the string.

=cut

sub at_eos
{
   my $self = shift;

   $self->skip_ws;

   my $pos = pos $self->{str};

   return 1 if defined $pos and $pos >= length $self->{str};

   return 0 unless defined $self->{endofscope};

   # No /g so we won't actually alter pos()
   my $at_eos = $self->{str} =~ m/\G$self->{endofscope}/;

   return $at_eos;
}

=head2 $level = $parser->scope_level

Returns the number of nested C<scope_of> calls that have been made.

=cut

sub scope_level
{
   my $self = shift;
   return $self->{scope_level};
}

=head1 STRUCTURE-FORMING METHODS

The following methods may be used to build a grammatical structure out of the
defined basic token-parsing methods. Each takes at least one code reference,
which will be passed the actual C<$parser> object as its first argument.

=cut

=head2 $ret = $parser->maybe( $code )

Attempts to execute the given C<$code> reference in scalar context, and
returns what it returned. If the code fails to parse by calling the C<fail>
method then none of the input string will be consumed; the current parsing
position will be restored. C<undef> will be returned in this case.

This may be considered to be similar to the C<?> regexp qualifier.

 sub parse_declaration
 {
    my $self = shift;

    [ $self->parse_type,
      $self->token_ident,
      $self->maybe( sub {
         $self->expect( "=" );
         $self->parse_expression
      } ),
    ];
 }

=cut

sub maybe
{
   my $self = shift;
   my ( $code ) = @_;

   my $pos = pos $self->{str};

   my $committed = 0;
   local $self->{committer} = sub { $committed++ };

   my $ret;
   eval { $ret = $code->( $self ); 1 } and return $ret;
   my $e = $@;

   pos($self->{str}) = $pos;

   die $e if $committed or not eval { $e->isa( "Parser::MGC::Failure" ) };
   return undef;
}

=head2 $ret = $parser->scope_of( $start, $code, $stop )

Expects to find the C<$start> pattern, then attempts to execute the given
C<$code> reference, then expects to find the C<$stop> pattern. Returns
whatever the code reference returned.

While the code is being executed, the C<$stop> pattern will be used by the
token parsing methods as an end-of-scope marker; causing them to raise a
failure if called at the end of a scope.

 sub parse_block
 {
    my $self = shift;

    $self->scope_of( "{", sub { $self->parse_statements }, "}" );
 }

=cut

sub scope_of
{
   my $self = shift;
   my ( $start, $code, $stop ) = @_;

   ref $stop or $stop = qr/\Q$stop/;

   $self->expect( $start );
   local $self->{endofscope} = $stop;
   local $self->{scope_level} = $self->{scope_level} + 1;

   my $ret = $code->( $self );

   $self->expect( $stop );

   return $ret;
}

=head2 $ret = $parser->list_of( $sep, $code )

Expects to find a list of instances of something parsed by C<$code>,
separated by the C<$sep> pattern. Returns an ARRAY ref containing a list of
the return values from the C<$code>.

This method does not consider it an error if the returned list is empty; that
is, that the scope ended before any item instances were parsed from it.

 sub parse_numbers
 {
    my $self = shift;

    $self->list_of( ",", sub { $self->token_int } );
 }

=cut

sub list_of
{
   my $self = shift;
   my ( $sep, $code ) = @_;

   ref $sep or $sep = qr/\Q$sep/;

   my @ret;

   while( !$self->at_eos ) {
      push @ret, scalar $code->( $self );

      $self->skip_ws;
      $self->{str} =~ m/\G$sep/gc or last;
   }

   return \@ret;
}

=head2 $ret = $parser->sequence_of( $code )

A shortcut for calling C<list_of> with an empty string as separator; expects
to find at least one instance of something parsed by C<$code>, separated only
by skipped whitespace.

This may be considered to be similar to the C<+> or C<*> regexp qualifiers.

 sub parse_statements
 {
    my $self = shift;

    $self->sequence_of( sub { $self->parse_statement } );
 }

=cut

sub sequence_of
{
   my $self = shift;
   my ( $code ) = @_;

   return $self->list_of( "", $code );
}

=head2 $ret = $parser->one_of( @codes )

Expects that one of the given code references can parse something from the
input, returning what it returned. Each code reference may indicate a failure
to parse by calling the C<fail> method.

This may be considered to be similar to the C<|> regexp operator for forming
alternations of possible parse trees.

 sub parse_statement
 {
    my $self = shift;

    $self->one_of(
       sub { $self->parse_declaration; $self->expect(";") },
       sub { $self->parse_expression; $self->expect(";") },
       sub { $self->parse_block },
    );
 }

=cut

sub one_of
{
   my $self = shift;

   while( @_ ) {
      my $pos = pos $self->{str};

      my $committed = 0;
      local $self->{committer} = sub { $committed++ };

      my $ret;
      eval { $ret = shift->( $self ); 1 } and return $ret;
      my $e = $@;

      pos( $self->{str} ) = $pos;

      die $e if $committed or not eval { $e->isa( "Parser::MGC::Failure" ) };
   }

   $self->fail( "Found nothing parseable" );
}

=head2 $parser->commit

Calling this method will cancel the backtracking behaviour of the innermost
C<maybe> or C<one_of> structure forming method. That is, if later code then
calls C<fail>, the exception will be propagated out of C<maybe>, and no
further code blocks will be attempted by C<one_of>.

Typically this will be called once the grammatical structure of an
alternation has been determined, ensuring that any further failures are raised
as real exceptions, rather than by attempting other alternatives.

 sub parse_statement
 {
    my $self = shift;

    $self->one_of(
       ...
       sub {
          $self->scope_of( "{",
             sub { $self->commit; $self->parse_statements; },
          "}" ),
       },
    );
 }

=cut

sub commit
{
   my $self = shift;
   if( $self->{committer} ) {
      $self->{committer}->();
   }
   else {
      croak "Cannot commit except within a backtrack-able structure";
   }
}

=head1 TOKEN PARSING METHODS

The following methods attempt to consume some part of the input string, to be
used as part of the parsing process.

=cut

sub skip_ws
{
   my $self = shift;

   my $ws = $self->{patterns}{ws};
   my $c  = $self->{patterns}{comment};

   {
      1 while $self->{str} =~ m/\G$ws/gc or
              ( $c and $self->{str} =~ m/\G$c/gc );

      return if pos( $self->{str} ) < length $self->{str};

      return unless $self->{reader};

      my $more = $self->{reader}->( $self );
      if( defined $more ) {
         my $pos = pos( $self->{str} );
         $self->{str} .= $more;
         pos( $self->{str} ) = $pos;

         redo;
      }

      undef $self->{reader};
      return;
   }
}

=head2 $parser->expect( $string )

=head2 $parser->expect( qr/pattern/ )

Expects to find a literal string or regexp pattern match, and consumes it.
This method returns the string that was captured.

=cut

sub expect
{
   my $self = shift;
   my ( $expect ) = @_;

   ref $expect or $expect = qr/\Q$expect/;

   $self->skip_ws;
   $self->{str} =~ m/\G($expect)/gc or
      $self->fail( "Expected $expect" );

   return $1;
}

=head2 $int = $parser->token_int

Expects to find an integer in decimal, octal or hexadecimal notation, and
consumes it. Negative integers, preceeded by C<->, are also recognised.

=cut

sub token_int
{
   my $self = shift;

   $self->fail( "Expected integer" ) if $self->at_eos;

   $self->{str} =~ m/\G(-?)($self->{patterns}{int})/gc or
      $self->fail( "Expected integer" );

   my $sign = $1 ? -1 : 1;
   my $int = $2;

   $int =~ s/^0o/0/;

   return $sign * oct $int if $int =~ m/^0/;
   return $sign * $int;
}

=head2 $int = $parser->token_float

Expects to find a number expressed in floating-point notation; a sequence of
digits possibly prefixed by C<->, possibly containing a decimal point.

=cut

sub token_float
{
   my $self = shift;

   $self->fail( "Expected float" ) if $self->at_eos;

   $self->{str} =~ m/\G(-?(?:\d*\.\d+|\d+\.)(?:e-?\d+)?|-?\d+e-?\d+)/gci or
      $self->fail( "Expected float" );

   return $1 + 0;
}

=head2 $str = $parser->token_string

Expects to find a quoted string, and consumes it. The string should be quoted
using C<"> or C<'> quote marks.

=cut

sub token_string
{
   my $self = shift;

   $self->fail( "Expected string" ) if $self->at_eos;

   my $pos = pos $self->{str};

   $self->{str} =~ m/\G($self->{patterns}{string_delim})/gc or
      $self->fail( "Expected string delimiter" );

   my $delim = $1;

   $self->{str} =~ m/\G((?:\\.|[^\\])*?)$delim/gc or
      pos($self->{str}) = $pos, $self->fail( "Expected contents of string" );

   my $string = $1;

   # TODO: Unescape stuff like \\ and \n and whatnot

   return $string;
}

=head2 $ident = $parser->token_ident

Expects to find an identifier, and consumes it.

=cut

sub token_ident
{
   my $self = shift;

   $self->fail( "Expected identifier" ) if $self->at_eos;

   $self->{str} =~ m/\G($self->{patterns}{ident})/gc or
      $self->fail( "Expected identifier" );

   return $1;
}

=head2 $keyword = $parser->token_kw( @keywords )

Expects to find a keyword, and consumes it. A keyword is defined as an
identifier which is exactly one of the literal values passed in.

=cut

sub token_kw
{
   my $self = shift;
   my @acceptable = @_;

   $self->skip_ws;

   my $pos = pos $self->{str};

   defined( my $kw = $self->token_ident ) or
      return undef;

   grep { $_ eq $kw } @acceptable or
      pos($self->{str}) = $pos, $self->fail( "Expected any of ".join( ", ", @acceptable ) );

   return $kw;
}

package # hide from indexer
   Parser::MGC::Failure;

sub new
{
   my $class = shift;
   my $self = bless {}, $class;
   @{$self}{qw( message linenum col text )} = @_;
   return $self;
}

use overload '""' => "STRING";
sub STRING
{
   my $self = shift;

   # Column number only counts characters. There may be tabs in there.
   # Rather than trying to calculate the visual column number, just print the
   # indentation as it stands.

   my $indent = substr( $self->{text}, 0, $self->{col} );
   $indent =~ s/[^ \t]/ /g; # blank out all the non-whitespace

   return "$self->{message} on line $self->{linenum} at:\n" . 
          "$self->{text}\n" . 
          "$indent^\n";
}

# Provide fallback operators for cmp, eq, etc...
use overload fallback => 1;

=head1 TODO

=over 4

=item *

Unescaping of string constants; customisable

=item *

Easy ability for subclasses to define more token types

=item *

Investigate how well C<from_reader> can cope with buffer splitting across
other tokens than simply skippable whitespace

=back

=head1 AUTHOR

Paul Evans <leonerd@leonerd.org.uk>

=cut

0x55AA;
