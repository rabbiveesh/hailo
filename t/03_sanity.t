use strict;
use warnings;
use Hailo;
use Test::More tests => 4;

for my $storage (qw(Perl SQLite)) {
    my $hailo = Hailo->new(
        storage_class => $storage,
        ($storage eq 'SQLite'
            ? (brain_resource => ':memory:')
            : ()
        ),
    );
    my $string = "Congress\t shall\t make\t no\t law.";
    my $reply  = $string;
    $reply     =~ tr/\t//d;

    $hailo->learn($string);
    is($hailo->reply('make'), $reply, 'Learned string correctly');
    is($hailo->reply('respecting'), undef, "Hasn't learned this word yet");
}