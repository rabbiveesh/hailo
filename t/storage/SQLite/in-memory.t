use v5.10.0;
use strict;
use warnings;
use Hailo;
use File::Temp qw(tempdir tempfile);
use File::Slurp qw<slurp>;
use Bot::Training;
use Test::More tests => 18;

# Dir to store our brains
my $dir = tempdir( "hailo-test-sqlite-in-memory-XXXX", CLEANUP => 1, TMPDIR => 1 );
my ($fh, $brain_file) = tempfile( DIR => $dir, SUFFIX => '.sqlite', EXLOCK => 0 );

my $trainfile = Bot::Training->new->file("starcraft")->file;
my @train = split /\n/, slurp($trainfile);

## Train *not* in memory
{
    my $hailo = Hailo->new(
        storage_class  => 'SQLite',
        brain          => $brain_file,
    );
    ok(!$hailo->_storage->_backup_memory_to_disk, "SQLite is not running in disk->memory->disk mode");

    isnt($hailo->brain, ':memory:',
         sprintf "Hailo is using %s as a brain, not :memory", $hailo->brain);
    ok(!$hailo->_storage->arguments->{in_memory},
       "SQLite's in_memory argument is false, so we're not running it hybrid disk->memory mode");

    # we need to learn something first so the DB file will be initialized
    $hailo->learn('foo bar baz');

    my $orig_size = -s $brain_file;
    $hailo->train(\@train);
    my $new_size = -s $brain_file;

    isnt($new_size, $orig_size, "Hailo wrote the things it learned to disk. Brain was $orig_size, now $new_size");
}

for my $save_on_exit (0, 1) {
    ## Train *in* memory
    my $after_train_size;
    {
        ok(-f $brain_file, "$brain_file still exists");

        my $orig_size = -s $brain_file;
        my $hailo = Hailo->new(
            save_on_exit   => $save_on_exit,
            storage_class  => 'SQLite',
            brain          => $brain_file,
            storage_args   => {
                in_memory      => 1,
            },
        );

        ok($hailo->_storage->_backup_memory_to_disk, "SQLite is running in disk->memory->disk mode");
        unlike($hailo->reply("mooYou"), qr/mooYou/, "Got a random from the loaded brain");
        $hailo->train([ map { "moo-$save_on_exit-$_" } @train ]);
        $after_train_size = -s $brain_file;
        {
            my $r = $hailo->reply("moo-$save_on_exit-You");
            like($r, qr/moo-$save_on_exit-You/i, "got a reply to a word that now exist: $r");
        }
        is($after_train_size, $orig_size, "Hailo is writing to memory, not disk. Brain was $orig_size, now $after_train_size");
    }

    ## Test that it was saved to disk
    {
        my $get_hailo = sub {
            my $hailo = Hailo->new(
                storage_class  => 'SQLite',
                brain          => $brain_file,
            );
        };
        my $after_save_size = -s $brain_file;

        if ($save_on_exit == 0) {
            cmp_ok($after_train_size, "==", $after_save_size, "Hailo wasn't saved to disk, was $after_train_size, now $after_save_size");
            my $hailo = $get_hailo->();
            my $r = $hailo->reply("moo-$save_on_exit-You");
            unlike($r, qr/moo-$save_on_exit-You/i, "got a reply to a word that now exist: $r");
        } elsif ($save_on_exit == 1) {
            cmp_ok($after_train_size, "<", $after_save_size, "Hailo was saved to disk, was $after_train_size, now $after_save_size");
            my $hailo = $get_hailo->();
            my $r = $hailo->reply("moo-$save_on_exit-You");
            like($r, qr/moo-$save_on_exit-You/i, "got a reply to a word that now exist: $r");
        } else {
            die "PANIC: Unknown '$save_on_exit' value";
        }
    }
}
