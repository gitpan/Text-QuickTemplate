=head1 NAME

Text::QuickTemplate - A simple, lightweight text fill-in class.

=head1 VERSION

This documentation describes v0.02 of Text::QuickTemplate, July 24, 2005.

=cut

package Text::QuickTemplate;

use strict;
use warnings;
use Readonly;

our $VERSION = '0.02';
Readonly our $DONTSET => [];

# Always export the $DONTSET variable
sub import
{
    my ($pkg) = caller;
    no strict 'refs';
    *{$pkg.'::DONTSET'} = \$DONTSET;
}

# Declare exception classes
use Exception::Class
(
    'QuickTemplate::X' =>
        { description => 'Generic Text::QuickTemplate exception',
        },
    'QuickTemplate::X::ParameterError' =>
        { isa         => 'QuickTemplate::X',
          description => 'Error in parameters to Text::QuickTemplate method',
        },
    'QuickTemplate::X::OptionError' =>
        { isa         => 'QuickTemplate::X',
          fields      => 'name',
          description => 'A bad option was passed to a Text::QuickTemplate method',
        },
    'QuickTemplate::X::KeyNotFound' =>
        { isa         => 'QuickTemplate::X',
          fields      => 'symbols',
          description => 'Could not resolve one or more symbols in template text',
        },
    'QuickTemplate::X::InternalError' =>
        { isa         => 'QuickTemplate::X',
          fields      => 'additional_info',
          description => 'Internal Text::QuickTemplate error.  Please contact the author.'
        },
);

# Class method to help caller catch exceptions
sub Exception::Class::Base::caught
{
    my $class = shift;
    return Exception::Class->caught($class);
}

# Croak-like location of error
sub QuickTemplate::X::location
{
    my ($pkg,$file,$line);
    my $caller_level = 0;
    while (1)
    {
        ($pkg,$file,$line) = caller($caller_level++);
        last if $pkg !~ /\A Text::QuickTemplate/x  &&  $pkg !~ /\A Exception::Class/x
    }
    return "at $file line $line";
}

# Die-like location of error
sub QuickTemplate::X::InternalError::location
{
    my $self = shift;
    return "at " . $self->file() . " line " . $self->line()
}

# Override full_message, to report location of error in caller's code.
sub QuickTemplate::X::full_message
{
    my $self = shift;

    my $msg = $self->message;
    return $msg  if substr($msg,-1,1) eq "\n";

    $msg =~ s/[ \t]+\z//;   # remove any trailing spaces (is this necessary?)
    return $msg . q{ } . $self->location() . qq{\n};
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

    ## Initializer
    # $obj->_initialize($boilerplate, $options);
    sub _initialize
    {
        my $self = shift;

        # Check whether any attribute has a value from another, earlier object.
        # This should never happen, if DESTROY is working, and nobody calls
        # _initialize on an already-initialized object.
        {
            my   @occupied;
            push @occupied, '%boilerplate_for'   if exists $boilerplate_for {$self};
            push @occupied, '%delimiters_for'    if exists $delimiters_for  {$self};
            push @occupied, '%regex_for'         if exists $regex_for       {$self};
            push @occupied, '%value_hashes_for'  if exists $value_hashes_for{$self};
            push @occupied, '%bad_keys_of'       if exists $bad_keys_of     {$self};

            QuickTemplate::X::InternalError->throw(
                message         => "Internal programing error: contact author.",
                additional_info => join(', ', @occupied))
                if @occupied;
        }

        # Check number and type of parameters
        my $whoami = ref($self) . " constructor";
        QuickTemplate::X::ParameterError->throw("Second argument to $whoami must be hash reference")
            if @_ == 2  &&  ref($_[1]) ne 'HASH';
        QuickTemplate::X::ParameterError->throw("Too many parameters to $whoami")
            if @_ > 2;
        QuickTemplate::X::ParameterError->throw("Missing boilerplate text parameter to $whoami")
            if @_ == 0;

        my $boilerplate = shift;
        my $options_ref = shift || {};

        $boilerplate_for{$self} = $boilerplate;
        if (exists $options_ref->{delimiters})
        {
            my $delim = $options_ref->{delimiters};

            QuickTemplate::X::OptionError->throw(
                message => "Bad option to $whoami\n"
                           . "delimiter value must be array reference",
                name => 'delimiter')
                unless ref($delim) eq 'ARRAY';

            QuickTemplate::X::OptionError->throw(
                message => "Bad option to $whoami\n"
                           . "delimiter arrayref must have exactly two values",
                name => 'delimiter')
                unless @$delim == 2;

            my ($ref0, $ref1) = (ref ($delim->[0]), ref($delim->[1]));
            QuickTemplate::X::OptionError->throw(
                message => "Bad option to $whoami\n"
                           . "delimiter values must be strings or regexes",
                name => 'delimiter')
                unless ($ref0 eq q{}  ||  $ref0 eq 'Regexp')
                    && ($ref1 eq q{}  ||  $ref1 eq 'Regexp');

            $delimiters_for{$self} = [ $ref0? $delim->[0] : quotemeta($delim->[0]),
                                       $ref0? $delim->[1] : quotemeta($delim->[1]) ];
        }
        else
        {
            $delimiters_for{$self} = [ quotemeta('{{'), quotemeta('}}') ];
        }

        # $1 is the keyword plus its delimiters; $2 is the keyword by itself.
        $regex_for{$self} =
            qr/( $delimiters_for{$self}[0]  (\w+)  $delimiters_for{$self}[1] )/xsm;

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
            QuickTemplate::X::ParameterError->throw("Argument to pre_fill() is not a hashref")
                if ref $arg ne 'HASH';
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
            QuickTemplate::X::ParameterError->throw("Argument to fill() is not a hashref")
                if ref $arg ne 'HASH';
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
            my $s = @$bk == 1? q{} : 's';
            my $bad_str = join ', ', @$bk;
            $bad_keys_of{$self} = [];   # reset in case exception is caught.
            QuickTemplate::X::KeyNotFound->throw(
                message => "Could not resolve the following symbol$s: $bad_str",
                symbols => $bk);
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
            return $whole_expr
                if ref($value) eq 'ARRAY'  &&  $value eq $DONTSET;

            return defined $value? $value : q{};
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
        my $out = q{};

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
powerful than Text::QuickTemplate.  When you need that power, they're
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
 # Dies with "could not resolve the following symbol: title"

 $bibl_3 = $book_t->fill({author => 'Isaac Asimov',
                          title  => $DONTSET });
 # yields: "<i>{{title}}</i>, by Isaac Asimov"


=head1 EXPORTS

This module exports the symbol C<$DONTSET> into the caller's
namespace.


=head1 REQUIREMENTS

This module is dependent upon the following other CPAN modules:

 Readonly
 Exception::Class


=head1 DIAGNOSTICS

Text::QuickTemplate uses Exception::Class objects for throwing
exceptions.  If you're not familiar with Exception::Class, don't
worry; these exception objects work just like C<$@> does with C<die>
and C<croak>, but they are easier to work with if you are trapping
errors.

All exceptions thrown by Text::QuickTemplate have a base class of
QuickTemplate::X.  You can trap errors with an eval block:

 eval { $letter = $template->fill(@hashrefs); };

and then check for errors as follows:

 if (QuickTemplate::X->caught())  {...

You can look for more specific errors by looking at a more specific
class:

 if (QuickTemplate::X::KeyNotFound->caught())  {...

Some exceptions provide further information, which may be useful
for your exception handling:

 if (my $ex = QuickTemplate::X::OptionError->caught())
 {
     warn "Bad option: " . $ex->name();
     ...

If you choose to (or cannot) handle a particular type of exception
(for example, there's not much to be done about a parameter error),
you should rethrow the error:

 if (my $ex = QuickTemplate::X->caught())
 {
     if ($ex->isa('QuickTemplate::X::SomethingUseful'))
     {
         ...
     }
     else
     {
         $ex->rethrow();
     }
 }

=over 4

=item * Parameter errors

Class: C<QuickTemplate::X::ParameterError>

You called a Text::QuickTemplate method with
one or more bad parameters.  Since this is almost certainly a coding
error, there is probably not much use in handling this sort of
exception.

As a string, this exception provides a human-readable message about
what the problem was.

=item * Option errors

Class C<QuickTemplate::X::OptionError>

There's an error in one or more options passed to the constructor
C<new>.

This exception has one method, C<name()>, which returns the name of
the option that had a problem (for example, 'C<delimiter>').

As a string, this exception provides a human-readable message about
what the problem was.

=item * Unresolved symbols

Class C<QuickTemplate::X::KeyNotFound>

One or more subsitution keywords in the template string were not found
in any of the value hashes passed to C<fill> or C<pre_fill>.  This
exception is thrown by C<fill>.

This exception has one method, C<symbols()>, which returns a reference
to an array containing the names of the keywords that were not found.

As a string, this exception resolves to C<"Could not resolve the
following symbols:"> followed by a list of the unresolved symbols.

=item * Internal errors

Class C<QuickTemplate::X::InternalError>

Something happened that I thought couldn't possibly happen.  I would
appreciate it if you could send me an email message detailing the
circumstances of the error.

=back

=head1 AUTHOR / COPYRIGHT

Eric J. Roode, roode@cpan.org

To avoid my spam filter, please include "Perl", "module", or this
module's name in the message's subject line, and/or GPG-sign your
message.

Copyright (c) 2005 by Eric J. Roode. All Rights Reserved.
This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.
