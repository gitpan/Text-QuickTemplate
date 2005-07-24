use strict;
use Test::More tests => 51;
use Text::QuickTemplate;

# Check that new() fails when it should.

sub begins_with
{
    my ($actual, $expected, $test_name) = @_;

    $actual = substr($actual, 0, length $expected);
    @_ =  ($actual, $expected, $test_name);
    goto &is;
}

my ($template, $x);

eval
{
    $template = Text::QuickTemplate->new(<<END_TEMPLATE, 'burp');
Dear {{to}},
    Have a {{day_type}} day.
Your {{relation}},
{{from}}
END_TEMPLATE
};

$x = $@;
isnt $x, q{},   q{Bad second argument to 'new'};

ok (QuickTemplate::X->caught(), q{Bad-arg exception caught});

ok (QuickTemplate::X::ParameterError->caught(),  q{Bad-arg exception is of proper type});

begins_with $x,
    "Second argument to Text::QuickTemplate constructor must be hash reference",
    "Bad-arg exception works as a string, too";


eval
{
    $template = Text::QuickTemplate->new(<<END_TEMPLATE, {a=>1}, 'burp');
Dear {{to}},
    Have a {{day_type}} day.
Your {{relation}},
{{from}}
END_TEMPLATE
};

$x = $@;
isnt $x, q{},   q{Too many arguments to 'new'};

ok(QuickTemplate::X->caught(), q{Too-many exception caught});

ok(QuickTemplate::X::ParameterError->caught(),  q{Too-many exception is of proper type});

begins_with $x,
    "Too many parameters to Text::QuickTemplate constructor",
    "Too-many exception works as a string, too";


eval
{
    $template = Text::QuickTemplate->new();
};

$x = $@;
isnt $x, q{},   q{Missing argument to 'new'};

ok(QuickTemplate::X->caught(), q{Missing arg exception caught});

ok(QuickTemplate::X::ParameterError->caught(),  q{Missing arg exception is of proper type});

begins_with $x,
    "Missing boilerplate text parameter to Text::QuickTemplate constructor",
    "Missing arg exception works as a string, too";


eval
{
    $template = Text::QuickTemplate->new(q{}, {delimiters => q{}});
};

$x = $@;
isnt $x, q{},   q{Delimiter: bad type};

ok(QuickTemplate::X->caught(), q{Bad delimiter option exception caught});

ok(QuickTemplate::X::OptionError->caught(),  q{Bad delimiter exception is of proper type});

is $x->name(), 'delimiter',  q{Bad option name specified (bad type)};

begins_with $x,
    "Bad option to Text::QuickTemplate constructor\ndelimiter value must be array reference",
    "Bad delimiter option exception works as a string, too";


eval
{
    $template = Text::QuickTemplate->new(q{}, {delimiters => []});
};

$x = $@;
isnt $x, q{},   q{Wrong# delimiters};

ok(QuickTemplate::X->caught(), q{Wrong# delimiters exception caught});

ok(QuickTemplate::X::OptionError->caught(),  q{Wrong# delimiters exception is of proper type});

is $x->name(), 'delimiter',  q{Bad option name specified (wrong# delimiters)};

begins_with $x,
    "Bad option to Text::QuickTemplate constructor\ndelimiter arrayref must have exactly two values",
    "Wrong# delimiters exception works as a string, too";

eval
{
    $template = Text::QuickTemplate->new(q{}, {delimiters => ['a', []]});
};

$x = $@;
isnt $x, q{},   q{Wrong type delimiters (sx)};

ok(QuickTemplate::X->caught(), q{Wrong type delimiters (sx) exception caught});

ok(QuickTemplate::X::OptionError->caught(),  q{Wrong type delimiters (sx) exception is of proper type});

is $x->name(), 'delimiter',  q{Bad option name specified (wrong type delimiters (sx))};

begins_with $x,
    "Bad option to Text::QuickTemplate constructor\ndelimiter values must be strings or regexes",
    "Wrong type delimiters (sx) exception works as a string, too";

eval
{
    $template = Text::QuickTemplate->new(q{}, {delimiters => [qr/a/, []]});
};

$x = $@;
isnt $x, q{},   q{Wrong type delimiters (rx)};

ok(QuickTemplate::X->caught(), q{Wrong type delimiters (rx) exception caught});

ok(QuickTemplate::X::OptionError->caught(),  q{Wrong type delimiters (rx) exception is of proper type});

is $x->name(), 'delimiter',  q{Bad option name specified (wrong type delimiters (rx))};

begins_with $x,
    "Bad option to Text::QuickTemplate constructor\ndelimiter values must be strings or regexes",
    "Wrong type delimiters (rx) exception works as a string, too";

eval
{
    $template = Text::QuickTemplate->new(q{}, {delimiters => [[], 'b']});
};

$x = $@;
isnt $x, q{},   q{Wrong type delimiters (xs)};

ok(QuickTemplate::X->caught(), q{Wrong type delimiters (xs) exception caught});

ok(QuickTemplate::X::OptionError->caught(),  q{Wrong type delimiters (xs) exception is of proper type});

is $x->name(), 'delimiter',  q{Bad option name specified (wrong type delimiters (xs))};

begins_with $x,
    "Bad option to Text::QuickTemplate constructor\ndelimiter values must be strings or regexes",
    "Wrong type delimiters (xs) exception works as a string, too";

eval
{
    $template = Text::QuickTemplate->new(q{}, {delimiters => [[], qr/b/]});
};

$x = $@;
isnt $x, q{},   q{Wrong type delimiters (xr)};

ok(QuickTemplate::X->caught(), q{Wrong type delimiters (xr) exception caught});

ok(QuickTemplate::X::OptionError->caught(),  q{Wrong type delimiters (xr) exception is of proper type});

is $x->name(), 'delimiter',  q{Bad option name specified (wrong type delimiters (xr))};

begins_with $x,
    "Bad option to Text::QuickTemplate constructor\ndelimiter values must be strings or regexes",
    "Wrong type delimiters (xr) exception works as a string, too";

eval
{
    $template = Text::QuickTemplate->new(q{}, {delimiters => [[], {}]});
};

$x = $@;
isnt $x, q{},   q{Wrong type delimiters (xx)};

ok(QuickTemplate::X->caught(), q{Wrong type delimiters (xx) exception caught});

ok(QuickTemplate::X::OptionError->caught(),  q{Wrong type delimiters (xx) exception is of proper type});

is $x->name(), 'delimiter',  q{Bad option name specified (wrong type delimiters (xx))};

begins_with $x,
    "Bad option to Text::QuickTemplate constructor\ndelimiter values must be strings or regexes",
    "Wrong type delimiters (xx) exception works as a string, too";


# How about some non-exceptions, to brighten our day?

eval
{
    $template = Text::QuickTemplate->new(q{}, {delimiters => ['a', 'b']});
};

is $@, q{},   q{Correct type delimiters (ss)};

eval
{
    $template = Text::QuickTemplate->new(q{}, {delimiters => ['a', qr/b/]});
};

is $@, q{},   q{Correct type delimiters (sr)};

eval
{
    $template = Text::QuickTemplate->new(q{}, {delimiters => [qr/a/, 'b']});
};

is $@, q{},   q{Correct type delimiters (rs)};

eval
{
    $template = Text::QuickTemplate->new(q{}, {delimiters => [qr/a/, qr/b/]});
};

is $@, q{},   q{Correct type delimiters (rr)};
