package Krang::Session;
use strict;
use warnings;

use Krang::DB qw(dbh);
use Apache::Session::MySQL;

=head1 NAME

Krang::Session - session handling for Krang

=head1 SYNOPSIS

  use Krang::Session qw(%session);

  # get some session data
  my $bang = $session{buck};

  # get the session id
  my $session_id = $session{_session_id};

  # set from session data
  $session{buck} = $bang + 1;

  # delete from the session hash
  delete $session{buck};

  # it's that simple

=head1 DESCRIPTION

This module provides access to a peristent hash per user session.
This is available both in Apache/mod_perl, where a user session lasts
from login to logout, and from shell scripts, where a user session
lasts from process start to process end.

The session hash should be used for data that must persist between
requests but is not permanent enough to be stored in the database.
The most obvious usage is to maintain state while editing an object
before eventually saving changes to the database.

B<NOTE> The session hash should not be used as a general mechanism to
speed up Krang.  This is not a cache, it is an intermediary data
store.

=head1 INTERFACE

Aside from the exported %session hash, the module supports the
following routines.

=cut

our %session;
our $tied = 0;
require Exporter;
our @ISA = ('Exporter');
our @EXPORT_OK = ('%session');

=over 4

=item C<< $session_id = Krang::Session->create() >>

Create a new session and return the session id, to be used in a later
call to C<load()>.  After this call, C<%session> is attached to the
new session.

=cut

sub create {
    my $pkg = shift;
    my $dbh = dbh();
    tie %session, 'Apache::Session::MySQL', undef, 
      { Handle     => $dbh,
        LockHandle => $dbh }
        or croak("Unable to create new session.");
    $tied = 1;

    my $session_id = $session{_session_id};
    croak("Unable to create new session, null session_id")
      unless defined $session_id;
    return $session_id;
}

=item C<< Krang::Session->load($session_id) >>

Loads a session by id.  After this call, C<%session> is attached to
the specified session.  If the session cannot be found, this routine
will croak().

=cut

sub load {
    my $pkg = shift;
    my $session_id = shift;
    my $dbh = dbh();

    tie %session, 'Apache::Session::MySQL', $session_id, 
      { Handle     => $dbh,
        LockHandle => $dbh }
        or croak("Unable to create new session.");
    $tied = 1;

    # touch a key to make sure it gets saved on unload,
    # Apache::Session will miss a change several levels down unless a
    # top-level value changes.
    $session{__load_count__}++;
}


=item C<< Krang::Session->unload() >>

Unloads the current session, saving modified state to disk.  If this
routine is not called then the session will be saved the next time a
session is loaded or when the process ends.

After this call, C<%session> will be unavailble until the next call to
C<load()>.

=cut

sub unload { 
    untie %session if $tied; 
    $tied = 0;
}

=item C<< Krang::Session->delete() >>

=item C<< Krang::Session->delete($session_id) >>

Deletes a session from the store, permanently.  A session id can be
specified, or the current session will be deleted.

=back

=cut

sub delete {
    my $pkg = shift;
    my $session_id = shift;
    my $dbh = dbh();

    if ($session_id) {
        tie my %doomed, 'Apache::Session::MySQL', $session_id, 
          { Handle     => $dbh,
            LockHandle => $dbh }
            or croak("Unable to create new session.");
        tied(%doomed)->delete();
        untie(%doomed);
    } elsif ($tied) {
        tied(%session)->delete();
        untie(%session);
        $tied = 0;
    }
}

=head1 TODO

Old sessions should be expired eventually.  It should be easy to add
this feature once the cron runner is in.

=cut

1;


