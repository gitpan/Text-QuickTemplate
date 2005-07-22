use strict;
use Test::More tests => 4;
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
         relation => $DONTSET,
         day_type => 'swell',
         from     => 'Harry',
    });
};

is $@, '',     q{Simple template fill didn't die};
is $letter1, <<END_RESULT,  q{First simple template fill worked.};
Dear Professor Dumbledore,
    Have a swell day.
Your {{relation}},
Harry
END_RESULT
