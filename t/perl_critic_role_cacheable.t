use Test2::V0 -no_srand => 1;
use Perl::Critic::Role::Cacheable;

package Perl::Critic::Cacheable {
  use parent 'Perl::Critic';
  use Role::Tiny::With ();

  Role::Tiny::With::with 'Perl::Critic::Role::Cacheable';
}

subtest 'very basic' => sub {

  my $critic = Perl::Critic::Cacheable->new;
  isa_ok $critic, 'Perl::Critic';
  ok $critic->can('new'), 'has new method';
  ok !$critic->can('around'), 'does not have around method';

};

done_testing;


