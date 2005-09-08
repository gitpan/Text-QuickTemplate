use strict;
use Test::More tests => 32;
use Text::QuickTemplate;

# Test printf-like functions.

sub begins_with
{
    my ($actual, $expected, $test_name) = @_;

    $actual = substr($actual, 0, length $expected);
    @_ =  ($actual, $expected, $test_name);
    goto &is;
}

my ($template, $letter, $x);

# QTprintf with no args (4)
eval
{
    $letter = QTprintf();
};
$x = $@;
isnt $x, q{},   q{No args to QTprintf};

ok(QuickTemplate::X->caught(), q{No-args printf exception caught});

ok(QuickTemplate::X::ParameterError->caught(),  q{No-args printf exception is of proper type});

begins_with $x,
    q{QTprintf() requires at least one argument},
    q{No-args printf exception works as a string, too};

# QTsprintf with no args (4)
eval
{
    $letter = QTsprintf();
};
$x = $@;
isnt $x, q{},   q{No args to QTsprintf};

ok(QuickTemplate::X->caught(), q{No-args sprintf exception caught});

ok(QuickTemplate::X::ParameterError->caught(),  q{No-args sprintf exception is of proper type});

begins_with $x,
    q{QTsprintf() requires at least one argument},
    q{No-args sprintf exception works as a string, too};

# QTfprintf with no args (4)
eval
{
    $letter = QTfprintf();
};
$x = $@;
isnt $x, q{},   q{No args to QTfprintf};

ok(QuickTemplate::X->caught(), q{No-args fprintf exception caught});

ok(QuickTemplate::X::ParameterError->caught(),  q{No-args fprintf exception is of proper type});

begins_with $x,
    q{QTfprintf() requires at least two arguments},
    q{No-args fprintf exception works as a string, too};


eval
{
    $letter = QTsprintf <<END_TEMPLATE, (qw/bad arguments/);
Dear {{to}},
    Have a {{day_type}} day.
Your {{relation}},
{{from}}
END_TEMPLATE
};

$x = $@;
isnt $x, q{},   q{No hashref args to QTsprintf};

ok(QuickTemplate::X->caught(), q{Not-hashref exception caught});

ok(QuickTemplate::X::ParameterError->caught(),  q{Not-hashref exception is of proper type});

begins_with $x,
    q{Argument to QTsprintf() is not a hashref},
    q{Not-hashref exception works as a string, too};

eval
{
    $letter = QTsprintf <<END_TEMPLATE, {foo => 'bar'}, 'burp';
Dear {{to}},
    Have a {{day_type}} day.
Your {{relation}},
{{from}}
END_TEMPLATE
};

$x = $@;
isnt $x, q{},   q{Not all args are hashref};

ok(QuickTemplate::X->caught(), q{Not-all-hashrefs exception caught});

ok(QuickTemplate::X::ParameterError->caught(),  q{Not-all-hashrefs exception is of proper type});

begins_with $x,
    q{Argument to QTsprintf() is not a hashref},
    q{Not-all-hashrefs exception works as a string, too};

eval
{
    $letter = QTsprintf <<END_TEMPLATE, {to   => 'Lord Voldemort'}, {from => 'Harry'};
Dear {{to}},
    Have a {{day_type}} day.
Your {{relation}},
{{from}}
END_TEMPLATE
};

$x = $@;
isnt $x, q{},   q{Not all symbols resolved};

ok(QuickTemplate::X->caught(), q{Not-all-symbols exception caught});

ok(QuickTemplate::X::KeyNotFound->caught(),  q{Not-all-symbols exception is of proper type});

begins_with $x,
    q{Could not resolve the following symbols: day_type, relation},
    q{Not-all-symbols exception works as a string, too};


# Finally, let's get a couple right.

undef $letter;
eval
{
    $letter = QTsprintf <<END_TEMPLATE,
Dear {{to}},
    Have a {{day_type}} day.
Your {{relation}},
{{from}}
END_TEMPLATE
    {to       => 'Lord Voldemort'},
    {from     => 'Harry'},
    {day_type => 'supercalifragilisticexpialidocious'},
    {relation => 'sworn enemy'};
};

$x = $@;
is $x, q{},   q{Normal (multiple hashrefs)};

is $letter, <<END_LETTER, q{Multiple hashrefs reurned correct result};
Dear Lord Voldemort,
    Have a supercalifragilisticexpialidocious day.
Your sworn enemy,
Harry
END_LETTER

undef $letter;
eval
{
    $letter = QTsprintf <<END_TEMPLATE,
Dear {{to}},
    Have a {{day_type}} day.
Your {{relation}},
{{from}}
END_TEMPLATE
    {to       => 'Lord Voldemort',
     from     => 'Harry',
     day_type => 'supercalifragilisticexpialidocious',
     relation => 'sworn enemy'};
};

$x = $@;
is $x, q{},   q{Normal (one hashref)};

is $letter, <<END_LETTER, q{One-hashref returned correct result};
Dear Lord Voldemort,
    Have a supercalifragilisticexpialidocious day.
Your sworn enemy,
Harry
END_LETTER


# Printf-style formatting
undef $letter;
eval
{
    $letter = QTsprintf <<END_TEMPLATE,
Dear {{to}},
    Have a {{day_type:.10s}} day.
Your {{relation}},
{{from}}
END_TEMPLATE
    {to       => 'Lord Voldemort',
     from     => 'Harry',
     day_type => 'supercalifragilisticexpialidocious',
     relation => 'sworn enemy'};
};

$x = $@;
is $x, q{},   q{Normal (one hashref, formatted)};

is $letter, <<END_LETTER, q{One-hashref formatted returned correct result};
Dear Lord Voldemort,
    Have a supercalif day.
Your sworn enemy,
Harry
END_LETTER


undef $letter;
eval
{
    $letter = QTsprintf <<END_TEMPLATE,
Dear {{to}},
    Enclosed is {{tuition:%.2f}} gold pieces,
to cover my tuition for the current school year.
    Have a {{day_type:.10s}} day.
Your {{relation}},
{{from}}
END_TEMPLATE
    {to       => "Hogwart's Bursar",
     from     => 'Harry Potter',
     tuition  => '10000',
     day_type => 'nice',
     relation => 'student'};
};

$x = $@;
is $x, q{},   q{Normal (one hashref, formatted)};

is $letter, <<END_LETTER, q{One-hashref formatted returned correct result};
Dear Hogwart's Bursar,
    Enclosed is 10000.00 gold pieces,
to cover my tuition for the current school year.
    Have a nice day.
Your student,
Harry Potter
END_LETTER
