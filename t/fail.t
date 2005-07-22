use strict;
use Test::More tests => 5;
BEGIN { use_ok('Text::QuickTemplate') };

sub begins_with
{
    my ($actual, $expected, $test_name) = @_;

    $actual = substr($actual, 0, length $expected);
    is $actual, $expected, $test_name;
}

my ($template, $letter1);

eval
{
    $template = Text::QuickTemplate->new(<<END_TEMPLATE);
Dear {{to}},
    Have a {{day_type}} day.
Your {{relation}},
{{from}}
END_TEMPLATE
};

is $@, '',   q{Simple template creation didn't die};

$letter1 = 'previous value';
eval
{
    $letter1 = $template->fill (
        {to       => 'Professor Dumbledore',
         day_type => 'swell',
         from     => 'Harry',
    });
};

begins_with $@, 'Could not resolve the following symbol: relation',
    q{One missing parameter reported correctly};

is $letter1, 'previous value',  q{Error handling didn't change string};

eval
{
    $letter1 = $template->fill (
        {to       => 'Professor Dumbledore',
         day_type => 'swell',
    });
};

begins_with $@, 'Could not resolve the following symbols: relation, from',
    q{Two missing parameters reported correctly};
