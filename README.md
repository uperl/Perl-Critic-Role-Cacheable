# Perl::Critic::Role::Cacheable ![static](https://github.com/uperl/Perl-Critic-Role-Cacheable/workflows/static/badge.svg) ![linux](https://github.com/uperl/Perl-Critic-Role-Cacheable/workflows/linux/badge.svg)

Add caching to a Perl::Critic subclass

# SYNOPSIS

```perl
package MyCritic {
  use Role::Tiny::With;
  with 'Perl::Critic::Role::Cacheable';
}
```

# DESCRIPTION

This [Role::Tiny](https://metacpan.org/pod/Role::Tiny) role modifies a subclass of [Perl::Critic](https://metacpan.org/pod/Perl::Critic) so that source files that are already
known to have no violations will not be critiqued again.  The cache uses a MD5 of the configuration
and the Perl source, so if either change then the critique will be run again.

# CONSTRUCTOR

## new

```perl
my $critic = MyCritic->new( -cacheable-filename => $filename, %options );
```

The constructor will work as normal except a new option `-cacheable-filename` will be added
which allows you to set an alternate location to store the cache in.

- -cacheable-filename

    The name of the file to store the cache in.  Defaults to `~/.perl-critic-role-cacheable`.

# PROPERTIES

## cacheable\_filename

```perl
my $filename = $critic->cacheable_filename;
```

The name of the file where the cache will be stored.

# METHODS

## cacheable\_save

```
$critic->cacheable_save;
```

Save the cache.

## critique

```
$critic->critique( $source_code );
```

The critique method will work as normal, except source files that have already been
critiqued and had no violations will not be checked again.

# CAVEATS

This role will only cache when filenames are provided to the ["critique"](#critique) method.  If you provide
Perl source as a scalar reference or as a [Perl::Critic::Document](https://metacpan.org/pod/Perl::Critic::Document), then no caching will be done.

# AUTHOR

Graham Ollis <plicease@cpan.org>

# COPYRIGHT AND LICENSE

This software is copyright (c) 2023 by Graham Ollis.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.
