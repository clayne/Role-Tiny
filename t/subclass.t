use strict;
use warnings;
use Test::More;
use Test::Fatal;

my $backcompat_called;
{
  package RoleExtension;
  use base 'Role::Tiny';

  sub apply_single_role_to_package {
    my $me = shift;
    $me->SUPER::apply_single_role_to_package(@_);
    $backcompat_called++;
  }
}
{
  package RoleExtension2;
  use base 'Role::Tiny';

  sub role_application_steps {
    $_[0]->SUPER::role_application_steps;
  }

  sub apply_single_role_to_package {
    my $me = shift;
    $me->SUPER::apply_single_role_to_package(@_);
    $backcompat_called++;
  }

}

{
  package Role1;
  $INC{'Role1.pm'} = __FILE__;
  use Role::Tiny;
  sub sub1 {}
}

{
  package Role2;
  $INC{'Role2.pm'} = __FILE__;
  use Role::Tiny;
  sub sub2 {}
}

{
  package Class1;
  RoleExtension->apply_roles_to_package(__PACKAGE__, 'Role1', 'Role2');
}

is $backcompat_called, 2,
  'overridden apply_single_role_to_package called for backcompat';

$backcompat_called = 0;
{
  package Class2;
  RoleExtension2->apply_roles_to_package(__PACKAGE__, 'Role1', 'Role2');
}
is $backcompat_called, 0,
  'overridden role_application_steps prevents backcompat attempt';

{
  package RoleExtension3;
  use base 'Role::Tiny';

  sub _composable_package_for {
    my ($self, $role) = @_;
    my $composed_name = 'Role::Tiny::_COMPOSABLE::'.$role;
    return $composed_name if $Role::Tiny::COMPOSED{role}{$composed_name};
    no strict 'refs';
    *{"${composed_name}::extra_sub"} = sub {};
    $self->SUPER::_composable_package_for($role);
  }
}

{
  package Class2;
  sub foo {}
}
{
  package Role3;
  $INC{'Role3.pm'} = __FILE__;
  use Role::Tiny;
  requires 'extra_sub';
}
ok eval { RoleExtension3->create_class_with_roles('Class2', 'Role3') },
  'requires is satisfied by subs generated by _composable_package_for';

{
  package Role4;
  $INC{'Role4.pm'} = __FILE__;
  use Role::Tiny;
  requires 'extra_sub2';
}
ok !eval { RoleExtension3->create_class_with_roles('Class2', 'Role4'); },
  'requires checked properly during create_class_with_roles';

SKIP: {
  skip "Class::Method::Modifiers not installed or too old", 1
    unless eval "use Class::Method::Modifiers 1.05; 1";
  package Role5;
  $INC{'Role5.pm'} = __FILE__;
  use Role::Tiny;
  around extra_sub2 => sub { my $orig = shift; $orig->(@_); };

  ::ok !eval { RoleExtension3->create_class_with_roles('Class3', 'Role4'); },
    'requires checked properly during create_class_with_roles';
}

done_testing;
