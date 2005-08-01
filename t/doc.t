use strict;
use Test::More tests => 18;
BEGIN { use_ok('Text::QuickTemplate') };

# Make sure the documentation examples are correct,
# so as not to confuse anyone.

sub begins_with
{
    my ($actual, $expected, $test_name) = @_;

    $actual = substr($actual, 0, length $expected);
    @_ =  ($actual, $expected, $test_name);
    goto &is;
}


my ($template, $letter1, $letter2);

# Doco from the README
eval
{
    $template = Text::QuickTemplate->new(<<END_TEMPLATE);
Dear {{to}},
    Have a {{day_type}} day.
Your {{relation}},
{{from}}
END_TEMPLATE
};

is $@, q{},   q{Simple template creation didn't die};

eval
{
    $letter1 = $template->fill (
        {to       => 'Professor Dumbledore',
         relation => 'friend',
         day_type => 'swell',
         from     => 'Harry',
    });
};

is $@, q{},     q{Simple template fill didn't die};
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

is $@, q{},     q{Second simple template fill didn't die};
is $letter2, <<END_RESULT,  q{Second simple template fill worked.};
Dear Lord Voldemort,
    Have a rotten day.
Your sworn enemy,
Harry
END_RESULT


# Doco from the POD

my ($book_t, $bibl_1, $bibl_2, $bibl_3, $bibl_4);
eval
{
    $book_t = Text::QuickTemplate->new('<i>{{title}}</i>, by {{author}}');
};

is ($@, q{}, q{No exception for bibliography template});

eval
{
    $bibl_1 = $book_t->fill({author => "Stephen Hawking",
                             title  => "A Brief History of Time"});
};

is ($@, q{}, q{No exception for creating bibliography 1});

is ($bibl_1, "<i>A Brief History of Time</i>, by Stephen Hawking",
    q{Correct result for bibliography 1});

eval
{
    $bibl_2 = $book_t->fill({author => "Dr. Seuss",
                             title  => "Green Eggs and Ham"});
};

is ($@, q{}, q{No exception for creating bibliography 2});

is ($bibl_2, "<i>Green Eggs and Ham</i>, by Dr. Seuss",
    q{Correct result for bibliography 2});

eval
{
    $bibl_3 = $book_t->fill({author => 'Isaac Asimov'});
};

my $x = $@;
isnt ($x, q{}, q{Exception when creating bibliography 3});

ok (QuickTemplate::X->caught(), q{Proper base exception caught});
ok (QuickTemplate::X::KeyNotFound->caught(), q{Proper specific exception caught});

is_deeply($x->symbols, ['title'], q{Missing symbols returned});

begins_with ($@, q{Could not resolve the following symbol: title},
             q{Exception-as-string formatted properly});

eval
{
    $bibl_4 = $book_t->fill({author => 'Isaac Asimov',
                             title  => $DONTSET });
};

is ($@, q{}, q{No exception for creating bibliography 4});

is ($bibl_4, "<i>{{title}}</i>, by Isaac Asimov",
    q{Correct result for bibliography 4});
