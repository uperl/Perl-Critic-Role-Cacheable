use Test2::V0 -no_srand => 1;
use experimental qw( signatures postderef );
use Perl::Critic::Role::Cacheable;
use Path::Tiny;

my @faux_violations;
my $call_count;

package MyCritic {
  use parent 'Perl::Critic';
  use Role::Tiny::With ();

  Role::Tiny::With::with 'Perl::Critic::Role::Cacheable';

  sub critique ($self, $source_code ) {
    $call_count++;
    my @old = @faux_violations;
    @faux_violations = ();
    return @old;
  }

  sub new ($self, @args) {
    $call_count = 0;
    return $self->SUPER::new(@args);
  }
}

subtest 'very basic' => sub {

  my $critic = MyCritic->new;
  isa_ok $critic, 'Perl::Critic';
  ok $critic->can('new'), 'has new method';
  ok !$critic->can('around'), 'does not have around method';

};

subtest 'cache' => sub {
  my $root = Path::Tiny->tempdir;

  my @perl_source = (map { $root->child($_) } qw( source1.pl source2.pm));
  $perl_source[0]->spew('foo');
  $perl_source[1]->spew('bar');

  my $profile = $root->child('profile');
  $profile->spew('');

  my $cache = $root->child('cache');

  subtest 'first run (no cache)' => sub {
    my $critic = MyCritic->new(
      -profile => "$profile",
      '-cacheable-filename' => "$cache"
    );

    is(
      [$critic->critique("$perl_source[0]")],
      [],
      "call \$critic->critique(\"$perl_source[0]\") = []",
    );

    @faux_violations = ('a','b','x');

    is(
      [$critic->critique("$perl_source[1]")],
      ['a','b','x'],
      "call \$critic->critique(\"$perl_source[1]\") = [a,b,x]",
    );

    is $call_count, 2, 'expected call count';
    $critic->cacheable_save;

    ok -r $cache, 'created cache file';
  };

  subtest 'second run (with cache)' => sub {
    my $critic = MyCritic->new(
      -profile => "$profile",
      '-cacheable-filename' => "$cache"
    );

    is(
      [$critic->critique("$perl_source[0]")],
      [],
      "call \$critic->critique(\"$perl_source[0]\") = []",
    );

    @faux_violations = ('a','b','x');

    is(
      [$critic->critique("$perl_source[1]")],
      ['a','b','x'],
      "call \$critic->critique(\"$perl_source[1]\") = [a,b,x]",
    );

    is $call_count, 1, 'expected call count';
  };

  subtest 'third run with change to source file' => sub {
    $perl_source[0]->spew('baz');

    my $critic = MyCritic->new(
      -profile => "$profile",
      '-cacheable-filename' => "$cache"
    );

    is(
      [$critic->critique("$perl_source[0]")],
      [],
      "call \$critic->critique(\"$perl_source[0]\") = []",
    );

    @faux_violations = ('a','b','x');

    is(
      [$critic->critique("$perl_source[1]")],
      ['a','b','x'],
      "call \$critic->critique(\"$perl_source[1]\") = [a,b,x]",
    );

    is $call_count, 2, 'expected call count';
  };

  subtest 'forth run with change to profile' => sub {
    $perl_source[0]->spew('foo');
    $profile->spew('; just a comment');

    my $critic = MyCritic->new(
      -profile => "$profile",
      '-cacheable-filename' => "$cache"
    );

    is(
      [$critic->critique("$perl_source[0]")],
      [],
      "call \$critic->critique(\"$perl_source[0]\") = []",
    );

    @faux_violations = ('a','b','x');

    is(
      [$critic->critique("$perl_source[1]")],
      ['a','b','x'],
      "call \$critic->critique(\"$perl_source[1]\") = [a,b,x]",
    );

    is $call_count, 2, 'expected call count';
  };

  subtest 'forth run with change to arguments' => sub {
    my $profile = $root->child('profile2');
    $profile->spew('');

    my $critic = MyCritic->new(
      -profile => "$profile",
      '-cacheable-filename' => "$cache"
    );

    is(
      [$critic->critique("$perl_source[0]")],
      [],
      "call \$critic->critique(\"$perl_source[0]\") = []",
    );

    @faux_violations = ('a','b','x');

    is(
      [$critic->critique("$perl_source[1]")],
      ['a','b','x'],
      "call \$critic->critique(\"$perl_source[1]\") = [a,b,x]",
    );

    is $call_count, 2, 'expected call count';
  };

};

done_testing;
