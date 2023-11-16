use warnings;
use 5.020;
use experimental qw( postderef signatures );

package Perl::Critic::Role::Cacheable {

  # ABSTRACT: Add caching to a Perl::Critic subclass

=head1 SYNOPSIS

 package MyCritic {
   use Role::Tiny::With;
   with 'Perl::Critic::Role::Cacheable';
 }

=head1 DESCRIPTION

This L<Role::Tiny> role modifies a subclass of L<Perl::Critic> so that source files that are already
known to have no violations will not be critiqued again.  The cache uses a MD5 of the configuration
and the Perl source, so if either change then the critique will be run again.

=cut

  use Role::Tiny;
  use File::Glob ();
  use Digest::MD5 ();
  use Cpanel::JSON::XS ();
  use Path::Tiny ();
  use Ref::Util ();

=head1 CONSTRUCTOR

=head2 new

 my $critic = MyCritic->new( -cacheable-filename => $filename, %options );

The constructor will work as normal except a new option C<-cacheable-filename> will be added
which allows you to set an alternate location to store the cache in.

=over 4

=item -cacheable-filename

The name of the file to store the cache in.  Defaults to C<~/.perl-critic-role-cacheable>.

=back

=cut

  around new => sub ($orig, $class, %args) {
     my $filename = delete $args{'-cacheable-filename'} // File::Glob::bsd_glob('~/.perl-critic-role-cacheable');
     my $self = $orig->($class, %args);

     my %cache;
     if(-e $filename) {
       foreach my $line ( Path::Tiny->new($filename)->lines_utf8 ) {
         chomp $line;
         my ( $md5, $filename ) = split /\s+/, $line;
         $cache{$filename} = $md5;
       }
     }

     $self->{_cacheable} = {
       filename => $filename,
       config_digest => do {
         my $digest = Digest::MD5->new;
         $digest->add(Cpanel::JSON::XS->new->canonical->encode(\%args));
         if($args{'-profile'}) {
           $digest->add(Path::Tiny->new($args{'-profile'})->slurp_raw);
         }
         $digest;
       },
       digest_ok => \%cache,
       digest_disk => {},
     };

     return $self;
  };

=head1 PROPERTIES

=head2 cacheable_filename

 my $filename = $critic->cacheable_filename;

The name of the file where the cache will be stored.

=cut

  sub cacheable_filename ($self) {
    return $self->{_cacheable}->{filename};
  }

  sub _cacheable_config_digest ($self) {
    return $self->{_cacheable}->{config_digest};
  }

  sub _cacheable_digest_ok ($self) {
    return $self->{_cacheable}->{digest_ok};
  }

  sub _cacheable_digest_disk ($self) {
    return $self->{_cacheable}->{digest_disk};
  }

=head1 METHODS

=cut

  sub _cacheable_compute_md5_from_disk ($self, $filename) {
    return $self->_cacheable_digest_disk->{$filename} //= do {
      my $digest = $self->_cacheable_config_digest->clone;
      $digest->add( Path::Tiny->new($filename)->slurp_raw );
      $digest->hexdigest;
    }
  }

  sub _cacheable_check_cache_ok ( $self, $filename ) {
    my $expected = $self->_cacheable_digest_ok->{$filename};
    return '' unless $expected;
    my $disk = $self->_cacheable_compute_md5_from_disk($filename);
    return $disk eq $expected;
  }

  sub _cacheable_mark_cache_ok ( $self, $filename ) {
    my $md5 = $self->_cacheable_compute_md5_from_disk($filename);
    $self->_cacheable_digest_ok->{$filename} = $md5;
  }


=head2 cacheable_save

 $critic->cacheable_save;

Save the cache.

=cut

  sub cacheable_save ($self) {
    my $fh = Path::Tiny->new($self->cacheable_filename)->openw;
    foreach my $filename (sort keys $self->_cacheable_digest_ok->%*) {
      my $md5 = $self->_cacheable_digest_ok->{$filename};
      say $fh "$md5 $filename";
    }
    close $fh;
  }

=head2 critique

 $critic->critique( $source_code );

The critique method will work as normal, except source files that have already been
critiqued and had no violations will not be checked again.

=cut

  around critique => sub ($orig, $self, $source_code) {

     $DB::single = 1;
     my $filename = !Ref::Util::is_ref $source_code ? Path::Tiny->new($source_code)->absolute->stringify : undef;
     if($filename) {
       return () if $self->_cacheable_check_cache_ok($filename);
     }

     my @violations = $orig->($self, $source_code);

     if($filename && @violations == 0) {
       $self->_cacheable_mark_cache_ok($filename);;
     }

     return @violations;
  };

}

1;

=head1 CAVEATS

This role will only cache when filenames are provided to the L</critique> method.  If you provide
Perl source as a scalar reference or as a L<Perl::Critic::Document>, then no caching will be done.

=cut
