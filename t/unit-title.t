use strict;
use warnings;

use Test::More;

use lib 'lib';
use CalibreServer::DB;

subtest 'display title strips author prefix' => sub {
    is(
        CalibreServer::DB::_display_title(
            'LaHaye, Tim - Left Behind 09 - Assassins',
            'LaHaye, Tim'
        ),
        'Left Behind 09 - Assassins',
        'exact author prefix is removed'
    );

    is(
        CalibreServer::DB::_display_title(
            'Larsson, Stieg - The Girl with the Dragon Tattoo',
            'Stieg, Larsson,'
        ),
        'The Girl with the Dragon Tattoo',
        'fuzzy author prefix is removed when tokenized names match'
    );
};

subtest 'display title keeps clean and edge titles unchanged' => sub {
    is(
        CalibreServer::DB::_display_title('The Women: A Novel', 'Hannah, Kristin'),
        'The Women: A Novel',
        'clean title stays unchanged'
    );

    is(
        CalibreServer::DB::_display_title('Butter', 'Yuzuki, Asako & Barton, Polly'),
        'Butter',
        'plain title stays unchanged'
    );

    is(
        CalibreServer::DB::_display_title('Skyrim', 'munky'),
        'Skyrim',
        'junk metadata title stays unchanged'
    );

    is(
        CalibreServer::DB::_display_title('Hannah, Kristin - ', 'Hannah, Kristin'),
        'Hannah, Kristin - ',
        'too-short stripped title falls back to original'
    );

    is(
        CalibreServer::DB::_display_title('Any Title', q{}),
        'Any Title',
        'empty author sort leaves title unchanged'
    );

    is(
        CalibreServer::DB::_display_title('Any Title', undef),
        'Any Title',
        'undef author sort leaves title unchanged'
    );
};

done_testing();
