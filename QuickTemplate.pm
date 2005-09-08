=for gpg
-----BEGIN PGP SIGNED MESSAGE-----
Hash: SHA1

=head1 NAME

Text::QuickTemplate - A simple, lightweight text fill-in class.

=head1 VERSION

This documentation describes v0.05 of Text::QuickTemplate, September 8, 2005.

=cut

package Text::QuickTemplate;

use strict;
use warnings;
use Readonly;

our $VERSION = '0.05';
Readonly our $DONTSET => [];    # Unique identifier

# Always export the $DONTSET variable
# Always export the QTprintf subroutines
sub import
{
    my ($pkg) = caller;
    no strict 'refs';
    *{$pkg.'::DONTSET'}   = \$DONTSET;
    *{$pkg.'::QTprintf'}  = \&QTprintf;
    *{$pkg.'::QTsprintf'} = \&QTsprintf;
    *{$pkg.'::QTfprintf'} = \&QTfprintf;
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

# Comma formatting.  From the Perl Cookbook.
sub commify ($)
{
    my $rev_num = reverse shift;  # The number to be formatted, reversed.
    $rev_num =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
    return scalar reverse $rev_num;
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
    my %defaults_for;
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
            push @occupied, '%defaults_for'      if exists $defaults_for    {$self};
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
        # $3 is the printf format, if any; $4 is the extended format.
        $regex_for{$self} =
            qr/(                                    # $1: capture whole expression
                 $delimiters_for{$self}[0]          # Opening delimiter
                 (\w+)                              # $2: keyword
                 (?:  :                             # Maybe a colon and...
                      %? (-? [\d.]* [A-Za-z]{1,2} ) #   $3: ...a printf format
                      (?:   :                       #   and maybe another colon
                            ([,\$]+) )?             #   $4: and extended format chars
                 )?
                 $delimiters_for{$self}[1]          # Closing delimiter
              )/xsm;

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
        delete $defaults_for    {$self};
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

    # Stack up hash values for later substitution
    sub default
    {
        my $self = shift;

        # Validate the parameters
        foreach my $arg (@_)
        {
            QuickTemplate::X::ParameterError->throw("Argument to default() is not a hashref")
                if ref $arg ne 'HASH';
        }
        push @{ $defaults_for{$self} }, @_;
        return;
    }

    # Clear any pre-stored hashes
    sub clear_values
    {
        my $self = shift;
        @{ $value_hashes_for{$self} } = [];
        @{ $defaults_for    {$self} } = [];
        return;
    }

    # Do the replacements.
    sub fill
    {
        my $self = shift;
        my @fill_hashes = @_;

        # Validate the parameters
        foreach my $arg (@fill_hashes)
        {
            QuickTemplate::X::ParameterError->throw("Argument to fill() is not a hashref")
                if ref $arg ne 'HASH';
        }

        my @hashes;
        push @hashes, @{ $value_hashes_for{$self}}  if exists $value_hashes_for{$self};
        push @hashes, @fill_hashes;
        push @hashes, @{ $defaults_for    {$self}}  if exists $defaults_for    {$self};

        # Fetch other attributes
        my $str = $boilerplate_for{$self};
        my $rex = $regex_for{$self};

        # Do the subsitution
        $bad_keys_of{$self} = [];
        $str =~ s/$rex/$self->_substitution_of(\@hashes, $1, $2, $3, $4)/ge;

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
        my ($values_aref, $whole_expr, $keyword, $format, $extend) = @_;
        my %special_opts = defined $extend? map {$_ => 1} split //, $extend, -1 : ();

        Value_Hash: foreach my $hashref (@$values_aref)
        {
            next unless exists $hashref->{$keyword};

            my $value = $hashref->{$keyword};

            # Special DONTSET value: leave the whole expression intact
            return $whole_expr
                if ref($value) eq 'ARRAY'  &&  $value eq $DONTSET;

            $value = q{}  if !defined $value;
            return $value if !defined $format;

            $value = sprintf "%$format", $value;

            # Special extended formatting
            if (defined $extend)
            {
                # Currently, ',' and '$' are defined
                my $v_len = length $value;
                $value = commify $value     if $special_opts{','};
                $value =~ s/([^ ])/\$$1/    if $special_opts{'$'};
                my $length_diff = length($value) - $v_len;
                $value =~ s/^ {0,$length_diff}//;
                $length_diff = length($value) - $v_len;
                $value =~ s/ {0,$length_diff}$//;
            }

            return $value;
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



# printf-like convenience functions

sub QTprintf
{
    my $string = QT_printf_guts('QTprintf', @_);
    print $string;
}

sub QTsprintf
{
    return QT_printf_guts('QTsprintf', @_);
}

sub QTfprintf
{
    QuickTemplate::X::ParameterError->throw
        ("QTfprintf() requires at least two arguments")
        if @_ < 2;

    my $fh = shift;
    print {$fh} QT_printf_guts('QTfprintf', @_);
}

sub QT_printf_guts
{
    my $which = shift;
    QuickTemplate::X::ParameterError->throw
        ("$which() requires at least one argument")
        if @_ == 0;

    my $format = shift;
    my @value_hashes = @_;

    # Validate the parameters
    foreach my $arg (@value_hashes)
    {
        QuickTemplate::X::ParameterError->throw
            ("Argument to $which() is not a hashref")
            if ref $arg ne 'HASH';
    }

    my $template = Text::QuickTemplate->new ($format);
    return $template->fill(@value_hashes);
}

1;
__END__


=head1 SYNOPSIS

 # Create and fill a template:
 $template = Text::QuickTemplate->new($string, \%options);

 # Set default values:
 $template->default(\%values);

 # Set some override values:
 $template->pre_fill(\%values);

 # Fill it in, rendering the result string:
 $result = $template->fill(\%values);

 # printf-like usage
 QTprintf ($format, \%values);

 # sprintf-like usage
 $result = QTsprintf ($filehandle, $format, \%values);

 # fprintf-like usage (print to a filehandle)
 QTfprintf ($filehandle, $format, \%values);


=head1 OPTIONS

 delimiters => [ '{{', '}}' ];          # may be strings
 delimiters => [ qr/\{\{/, qr/\}\}/ ];  # and/or regexps


=head1 DESCRIPTION

There are many templating modules on CPAN.  They're all far, far more
powerful than Text::QuickTemplate.  When you need that power, they're
wonderful.  But when you don't, they're overkill.

This module provides a very simple, lightweight, quick and easy
templating mechanism for when you don't need those other
powerful-but-cumbersome modules.

First, you create a template object that contains the boilerplate
text.  See the next section for information on how to format it
properly.

Then, when it is necessary to render the final text (with placeholders
filled in), you use the L</fill> method, passing it one or more
references of hashes of values to be substituted into the original
boilerplate text.  The special value $DONTSET indicates that the
keyword (and its delimiters) are to remain in the boilerplate text,
unsubstituted.

That's it.  No control flow, no executable content, no filesystem
access.  Never had it, never will.

=head1 TEMPLATE FORMAT

When you create a template object, or when you use one of the
printf-like functions, you must supply a I<template>, which is a
string that contains I<placeholders> that will be filled in later (by
the L</fill> method).  All other text in the template will remain
undisturbed, as-is, unchanged.

I<Examples:>

 'This is a template.'
 'Here's a placeholder: {{fill_me_in}}'
 'Can occur multiple times: {{name}} {{phone}} {{name}}'
 'Optionally, can use printf formats: {{name:20s}} {{salary:%.2f}}'
 'Fancier formats: {{salary:%.2f:,$}}'

Substitution placeholders within the text are indicated by keywords,
set off from the surrounding text by a pair of delimiters.  (By
default the delimters are C<{{> and C<}}>, because that's easy to
remember, and since double curly braces are rare in programming
languages [and natural languages]).

Keywords between the delimiters must be comprised entirely of "word"
characters (that is, alphabetics, numerics, and the underscore), and
there must be no spaces or other characters between the keyword and
its delimiters.  This strictness is considered a feature.

Each keyword may optionally be followed (still within the delimiters)
by a colon (C<:>) and a printf format.  If a format is specified, it
will be used to format the entry when expanded.  The format may omit
the leading C<%> symbol, or it may include it.

If a printf format is supplied, it may optionally be followed by
another colon and zero or more special "extended formatting"
characters.  Currently, two such characters are recognized: C<,>
(comma) and C<$> (dollar sign).  Each of these is only useful if the
placeholder is being replaced by a number.  If a comma character is
used, commas will be inserted every three positions to the left of the
decimal point.  If a dollar-sign character is used, a dollar sign will
be placed immediately to the left of the first digit of the number.


=head1 COMMON MISTAKE

If Text::QuickTemplate does not expand a placeholder, check to make
sure that you did not include any spaces around the placeholder name,
and did not use any non-"word" (regex C<\W>) characters in the name.
Text::QuickTemplate is very strict about spaces and other characters;
this is so that a non-placeholder does not get expanded by mistake.

 Right: {{lemon}}
 Right: {{pi:%.9f}}
 Wrong: {{ lemon }}
 Wrong: {{lemon pie}}
 Wrong: {{pi: %.9f}}

Text::QuickTemplate will silently leave incorrectly-formatted
placeholders alone.  This is in case you are generating code; you
don't want something like

 sub foo {{bar => 1}};

to be mangled or to generate errors.

=head1 METHODS

=over 4

=item new

Constructor.

 $template_object = Text::QuickTemplate->new($boilerplate, \%options);

Creates a new Text::QuickTemplate object.  The boilerplate text string
parameter is mandatory; the hashref of options is optional.

Currently, the only option permitted is C<delimiters>, which is a
reference to an array of two strings (or compiled regular expresions):
a starting delimiter and an ending delimiter.

=item fill

Render the formatted string.

 $result_string = $template->fill($hashref);
 $result_string = $template->fill($hashref, $hashref, ...);

Replaces all of the placeholders within the template with values from
the hashref(s) supplied.

For each placeholder, the hashrefs are examined in turn for a matching
key.  As soon as one is found, the template moves on to the next
placeholder.  Another way of looking at this behavior is "The first
hashref that fulfills a given placeholder... wins."

If the resulting value is the special constant C<$DONTSET>, the
placeholder is left intact in the template.

If no value for a placeholder is found among any of the hash
references passed, an exception is thrown.

=item pre_fill

Set values without rendering.

 $template->pre_fill($hashref, ...);

Specifies one or more sets of key=>value pairs to be used by the
L</fill> method in addition to (and higher priority than) the ones
passed to L</fill>.

This can be useful if some template values are set when the template
is created, but the template is filled elsewhere in the program,
and you don't want to pass variables around.

=item default

Set default values without rendering.

 $template->default($hashref, ...);

Like L</pre_fill>, specifies key=>value pairs to be used by L</fill>,
but where L</pre_fill>'s values have a higher priority than those
specified by L</fill>, L</default>'s are I<lower>.  This can be used
at the time the object is created to give default values that only get
used if the call to L</fill> (or L</pre_fill>) don't override them.

=item clear_values

Clear default and pre-filled values.

 $template->clear_values();

Removes any L</pre_fill>ed or L</default> hash references in the
object.

=back

=head1 FUNCTIONS

=over 4

=item QTprintf

Render and print.

 QTprintf $format, \%values

Like Perl's printf, QTprintf takes a format string and a list of
values.  Unlike Perl's printf, the placeholders and values have names.
Like Perl's printf, the result string is sent to the default
filehandle (usually STDOUT).

This is equivalent to:

 my $template = Text::QuickTemplate->new ($format);
 print $template->fill (\%values);

QTprintf returns the same value as printf.

The original inspiration for this module came as the author was
scanning through a long and complex list of arguments to a printf
template, and lost track of which value when into which position.

=item QTsprintf

Render to string.

 $string = QTsprintf $format, \%values;

Same as L</QTprintf>, except that it returns the formatted string
instead of sending it to the default filehandle.

This is equivalent to:

 $string = do { my $t = Text::QuickTemplate->new($format);
                $t->fill (\%values)  };

=item QTfprintf

Render and print to filehandle.

 QTfprintf $filehandle, $format, \%values;

Like L</QTprintf>, except that it sends the formatted string to the
filehandle specified, instead of to the currently-selected filehandle.

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
 # Dies with "Could not resolve the following symbol: title"

 $bibl_4 = $book_t->fill({author => 'Isaac Asimov',
                          title  => $DONTSET });
 # yields: "<i>{{title}}</i>, by Isaac Asimov"

 # Example using format specification:
 $report_line = Text::QuickTemplate->new('{{Name:-20s}} {{Grade:10d}}');
 print $report_line->fill({Name => 'Susanna', Grade => 4});
 # prints "Susanna                       4"

 $line = QTsprintf '{{Name:-20s}} {{Grade:10d}}', {Name=>'Gwen', Grade=>6};
 # $line is now "Gwen                          6"

 QTfprintf *STDERR, '{{number:-5.2f}}', {number => 7.4};
 # prints "7.40 " to STDERR.

 # Example using extended formatting characters:
 $str = QTsprintf '{{widgets:%10d:,}} at {{price:%.2f:,$}} each',
                   {widgets => 1e6, price => 1234};
 # $str is now: " 1,000,000 at $1,234.00 each"

=head1 EXPORTS

This module exports the following symbols into the caller's namespace:

 $DONTSET
 QTprintf
 QTsprintf
 QTfprintf


=head1 REQUIREMENTS

This module is dependent upon the following other CPAN modules:

 Readonly
 Exception::Class


=head1 DIAGNOSTICS

Text::QuickTemplate uses L<Exception::Class> objects for throwing
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

If you choose not to (or cannot) handle a particular type of exception
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

You called a Text::QuickTemplate method with one or more bad
parameters.  Since this is almost certainly a coding error, there is
probably not much use in handling this sort of exception.

As a string, this exception provides a human-readable message about
what the problem was.

=item * Option errors

Class C<QuickTemplate::X::OptionError>

There's an error in one or more options passed to the constructor
L</new>.

This exception has one method, C<name()>, which returns the name of
the option that had a problem (for example, 'C<delimiters>').

As a string, this exception provides a human-readable message about
what the problem was.

=item * Unresolved symbols

Class C<QuickTemplate::X::KeyNotFound>

One or more subsitution keywords in the template string were not found
in any of the value hashes passed to L</fill>, L</pre_fill>, or
L</default>.  This exception is thrown by L</fill>.

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

=begin gpg

-----BEGIN PGP SIGNATURE-----
Version: GnuPG v1.4.1 (Cygwin)

iD8DBQFDIMDgY96i4h5M0egRAt/UAKD6eA4mpuVM/HdTdkmyChrBIA2zwwCcD273
mM5oDwpOTsWGgTIBOC/IHY0=
=6qE6
-----END PGP SIGNATURE-----

=end gpg
