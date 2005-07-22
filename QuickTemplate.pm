=head1 NAME

Text::QuickTemplate - A simple, lightweight text fill-in class.

=head1 VERSION

This documentation describes v0.01 of Text::QuickTemplate, July 22, 2005.

=cut

package Text::QuickTemplate;

use strict;
use warnings;
use Readonly;
use Carp;

our $VERSION = '0.01';
Readonly our $DONTSET => [];

# Always export the $DONTSET variable
sub import
{
    my ($pkg) = caller;
    no strict 'refs';
    *{$pkg.'::DONTSET'} = \$DONTSET;
}

## Constructor
# $object = Text::QuickTemplate->new($boilerplate, $options);
sub new
{
    my $class = shift;
    my $self  = \do { my $anonymous_scalar };
    bless $self, $class;
    $self->_initialize(@_);
    return $self;
}


{ # encapsulation enclosure

    # Attributes
    my %boilerplate_for;
    my %delimiters_for;
    my %regex_for;
    my %value_hashes_for;
    my %bad_keys_of;

    sub _initialize
    {
        my $self = shift;

        # Check number and type of parameter
        my $whoami = ref($self) . " constructor";
        croak "Second argument to $whoami must be hash reference"
            if @_ == 2  &&  ref($_[1]) ne 'HASH';
        croak "Too many parameters to $whoami"  if @_ > 2;
        croak "Missing boilerplate-text parameter to $whoami"  if @_ == 0;

        my $boilerplate = shift;
        my $options_ref = shift || {};

        $boilerplate_for{$self} = $boilerplate;
        if (my $delim = $options_ref->{delimiters})
        {
            croak "Bad option to $whoami\n"
                . "delimiter value must be array reference"
                unless ref($delim) eq 'ARRAY';

            croak "Bad option to $whoami\n"
                . "delimiter arrayref must have exactly two values"
                unless @$delim == 2;

            my ($ref0, $ref1) = (ref ($delim->[0]), ref($delim->[1]));
            croak "Bad option to $whoami\n"
                . "delimiter values must be strings or regexess"
                unless ($ref0 eq ''  ||  $ref0 eq 'REGEX')
                    && ($ref1 eq ''  ||  $ref1 eq 'REGEX');

            $delimiters_for{$self} = [ $ref0? $delim->[0] : quotemeta($delim->[0]),
                                       $ref0? $delim->[1] : quotemeta($delim->[1]) ];
        }
        else
        {
            $delimiters_for{$self} = [ quotemeta('{{'), quotemeta('}}') ];
        }

        $regex_for{$self} =
            qr/( $delimiters_for{$self}[0]  (\p{Id_Continue}+)  $delimiters_for{$self}[1] )/xsm;

        return;
    }

    sub DESTROY
    {
        my $self = shift;

        # Free up the hash entries we're using.
        delete $boilerplate_for {$self};
        delete $delimiters_for  {$self};
        delete $regex_for       {$self};
        delete $value_hashes_for{$self};
        delete $bad_keys_of     {$self};
    }

    # Stack up hash values for later substitution
    sub pre_fill
    {
        my $self = shift;

        # Validate the parameters
        foreach my $arg (@_)
        {
            croak "Argument to pre_fill() is not a hashref" if ref $arg ne 'HASH';
        }
        push @{ $value_hashes_for{$self} }, @_;
        return;
    }

    # Clear any pre-stored hashes
    sub clear_values
    {
        my $self = shift;
        @{ $value_hashes_for{$self} } = [];
        return;
    }

    # Do the replacements.
    sub fill
    {
        my $self = shift;
        my @hashes = @_;

        # Validate the parameters
        foreach my $arg (@hashes)
        {
            croak "Argument to fill() is not a hashref" if ref $arg ne 'HASH';
        }
        push @{ $value_hashes_for{$self} }, @hashes;

        # Fetch other attributes
        my $str = $boilerplate_for{$self};
        my $rex = $regex_for{$self};

        # Do the subsitution
        $bad_keys_of{$self} = [];
        $str =~ s/$rex/$self->_substitution_of($1, $2)/ge;

        # Restore the pre-set list of hashes (if any)
        splice @{ $value_hashes_for{$self} }, 0 - scalar(@hashes);

        # Any unfulfilled substitutions?
        my $bk = $bad_keys_of{$self};    # shortcut for the next few lines
        if (@$bk > 0)
        {
            my $s = @$bk == 1? '' : 's';
            my $bad_str = join ', ', @$bk;
            $bad_keys_of{$self} = [];   # reset in case exception is caught.
            croak "Could not resolve the following symbol$s: $bad_str";
        }

        return $str;
    }

    # Helper function for regular expression in fill(), above.
    sub _substitution_of
    {
        my $self = shift;
        my ($whole_expr, $keyword) = @_;

        Value_Hash: foreach my $hashref (@{$value_hashes_for{$self}})
        {
            next unless exists $hashref->{$keyword};

            my $value = $hashref->{$keyword};

            # Special DONTSET value: leave the whole expression intact
            if (ref($value) eq 'ARRAY'  &&  $value eq $DONTSET)
            {
                return $whole_expr;
            }

            return defined $value? $value : '';
        }

        # Never found a match?  Pity.
        # Store the bad keyword, and leave it intact in the string.
        push @{ $bad_keys_of{$self} }, $keyword;
        return $whole_expr;
    }


    # Debugging routine -- dumps a string representation of the object
    sub _dump
    {
        my $self = shift;
        my $out = '';

        $out .= qq{Boilerplate: "$boilerplate_for{$self}"\n};
        $out .= qq{Delimiters: [ "$delimiters_for{$self}[0]", "$delimiters_for{$self}[1]" ]\n};
        $out .= qq{Regex: $regex_for{$self}\n};
        $out .= qq{Value hashes: [\n};
        my $i = 0;
        my $vals = $value_hashes_for{$self} || [];
        for my $h (@$vals)
        {
            $out .= "    $i {\n";
            foreach my $k (sort keys %$h)
            {
                $out .= "        qq{$k} => qq{$h->{$k}}\n";
            }
            $out .= "       },\n";
            ++$i;
        }
        $out .= "]\n";

        my $bad_keys = $bad_keys_of{$self} || [];
        $out .= qq{Bad keys: [} . join(", ", @$bad_keys) . "]\n";;
        return $out;
    }

} # end encapsulation enclosure


1;
__END__


=head1 SYNOPSIS

 $template = Text::QuickTemplate->new($string, \%options);

 $result = $template->fill(\%values);


=head1 OPTIONS

 delimiters => [ '{{', '}}' ];          # may be strings
 delimiters => [ qr/\{\{/, qr/\{\{/ ];  # and/or regexps


=head1 DESCRIPTION

There are many templating modules on CPAN.  They're all far, far more
powerful than Text::QuickTemplate.  When you need that power, that's
wonderful.  But when you don't, they're overkill.

This module provides a very simple, lightweight, quick and easy
templating mechanism for when you don't need those other, powerful but
cumbersome, modules.

You create a template object that contains the boilerplate text.
Substitution placeholders within the text are indicated by keywords,
set off from the surrounding text by a pair of delimiters.  (By
default the delimters are C<{{> and C<}}>, since double curly braces
are rare in programming languages [and natural languages]).

Keywords between the delimiters must be comprised entirely of "word"
characters (that is, alphabetics, numerics, and the underscore), and
there must be no spaces or other characters between the keyword and
its delimiters.  This strictness is considered a feature.

When it is necessary to render the final text (with placeholders
filled in), you use the C<fill> method, passing it one or more
references of hashes of values to be substituted into the original
boilerplate text.  The special value $DONTSET indicates that the
keyword (and its delimiters) are to remain in the boilerplate text,
unsubstituted.

That's it.  No control flow, no executable content, no filesystem
access.  Never had it, never will.


=head1 METHODS

=over 4

=item new

 $template_object = Text::QuickTemplate->new($boilerplate, \%options);

Creates a new Text::QuickTemplate object.  The boilerplate text string
parameter is mandatory; the hashref of options is optional.

Currently, the only option permitted is C<delimiters>, which is a
reference to an array of two strings (or compiled regular expresions):
a starting delimiter and an ending delimiter.

=item fill

 $result_string = $template->fill($hashref);
 $result_string = $template->fill($hashref, $hashref, ...);

Replaces all of the placeholders within the template with values from
the hashref(s) supplied.

For each placeholder, the hashrefs are examined in turn for a matching
key.  As soon as one is found, the template moves on to the next
placeholder.  Another way of looking at this behavior is "The first
hashref that fulfills a given placeholder -- wins."

If the resulting value is C<$DONTSET>, the placeholder is left intact
in the template.

If no value for a placeholder is found among any of the hash
references passed, an exception is thrown.

=item pre_fill

 $template->pre_fill($hashref, ...);

Specifies one or more sets of key=>value pairs to be used by the
C<fill> method in addition to (and higher priority than) the ones
passed to C<fill>.

This can be useful if some template values are set when the template
is created, but the template is filled elsewhere in the program,
and you don't want to pass variables around.

=item clear_values

 $template->clear_values();

Removes any pre_filled hash references in the object.

=back


=head1 EXAMPLES

 $book_t = Text::QuickTemplate->new('<i>{{title}}</i>, by {{author}}');

 $bibl_1 = $book_t->fill({author => "Stephen Hawking",
                          title  => "A Brief History of Time"});
 # yields: "<i>A Brief History of Time</i>, by Stephen Hawking"

 $bibl_2 = $book_t->fill({author => "Dr. Seuss",
                          title  => "Green Eggs and Ham"});
 # yields: "<i>Green Eggs and Ham</i>, by Dr. Seuss"

 $bibl_3 = $book_t->fill({author => 'Isaac Asimov'});
 # Dies with "could not resolve the following symbols: title"

 $bibl_3 = $book_t->fill({author => 'Isaac Asimov',
                          title  => $DONTSET });
 # yields: "<i>{{title}}</i>, by Isaac Asimov"


=head1 EXPORTS

This module exports the symbol C<$DONTSET> into the caller's
namespace.


=head1 DIAGNOSTICS

=over 4

=item "Could not resolve the following symbols:"

The listed symbols were found in the template's boilerplate string,
but no matching key was found among any of the hash references passed
to C<pre_fill> or C<fill>.

=back

==head1 AUTHOR / COPYRIGHT

Eric J. Roode, roode@cpan.org

Copyright (c) 2005 by Eric J. Roode. All Rights Reserved.
This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.
