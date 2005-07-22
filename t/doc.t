use strict;
use Test::More tests => 6;
BEGIN { use_ok('Text::QuickTemplate') };

my ($template, $letter1, $letter2);

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

eval
{
    $letter1 = $template->fill (
        {to       => 'Professor Dumbledore',
         relation => 'friend',
         day_type => 'swell',
         from     => 'Harry',
    });
};

is $@, '',     q{Simple template fill didn't die};
is $letter1, <<END_RESULT,  q{First simple template fill worked.};
Dear Professor Dumbledore,
    Have a swell day.
Your friend,
Harry
END_RESULT

eval
{
    $letter2 = $template->fill (
        {to       => 'Lord Voldemort',
         relation => 'sworn enemy',
         day_type => 'rotten',
         from     => 'Harry',
    });
};

is $@, '',     q{Second simple template fill didn't die};
is $letter2, <<END_RESULT,  q{Second simple template fill worked.};
Dear Lord Voldemort,
    Have a rotten day.
Your sworn enemy,
Harry
END_RESULT
