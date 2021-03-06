package CentOS6_6::Platform;
use strict;
use warnings;

use base 'Krang::Platform';

use Cwd qw(cwd);

sub guess_platform {
    return 0 unless -e '/etc/redhat-release';
    open(RELEASE, '/etc/redhat-release') or return 0;
    my $release = <RELEASE>;
    close RELEASE;
    return 1 if $release =~ /Red Hat Enterprise Linux Server release 5/;
    return 1 if $release =~ /CentOS release 6.6/;
    return 0;
}

sub verify_dependencies {
    my ($pkg, %arg) = @_;

    # if this is Perl 5.8.0 then we need to check that the locale
    # isn't set to something UTF8-ish since that breaks this perl
    my $perl = join('.', (map { ord($_) } split("", $^V, 3)));
    if ($perl eq '5.8.0' and $ENV{LANG} and $ENV{LANG} =~ /UTF-8/) {
        die <<END;

Your version of Perl (v5.8.0) must not be used with a UTF-8 locale
setting.  You can fix this problem by either upgrading Perl to v5.8.3
or later or by editing /etc/sysconfig/i18n and choosing a non-UTF-8
LANG setting (ex: en_US).

END

    }

    return $pkg->SUPER::verify_dependencies(%arg);
}

# Overridden to correctly detect mysql-devel package on RH ES5 / x86_64
sub check_libmysqlclient {
    my ($pkg, %args) = @_;
    my @files = @{$args{lib_files}};

    # add /usr/lib/mysql and /usr/lib64/mysql since RedHat installs it in one of theose
    my @extra_dirs = ('/usr/lib/mysql', '/usr/lib64/mysql');
    for my $extra_dir (@extra_dirs) {
      if (-d $extra_dir) {
        opendir(DIR, $extra_dir) or die "Could not open $extra_dir for reading: $!";
        push(@files, grep { not -d $_ } readdir(DIR));
        closedir(DIR);
      }
    }

    unless (grep { /^libmysqlclient\./ } @files) {
        die <<END;

MySQL client development libraries not found.  These are required for the proper operation of Krang.

Install the MySQL client development libraries and try again.

END
    }
}


# setup init script so Krang starts on boot
sub finish_installation {
    my ($pkg, %arg) = @_;
    my %options = %{$arg{options}};

    my $init_script = "krang-". $options{HostName} .".init";    
    print "Installing Krang init.d script '$init_script'\n";

    my $old = cwd;
    chdir("/etc/init.d");

    my $InstallPath =  $options{InstallPath};
    unlink $init_script if -e $init_script;
    my $link_init = "ln -s $InstallPath/bin/krang_ctl $init_script";
    system($link_init) && die ("Can't link init script: $!");

    print "Setting $init_script to start on boot\n";

    my $chkconfig_bin = $pkg->find_bin(bin => 'chkconfig');

    my $chkconfig = "$chkconfig_bin --add $init_script";
    system($chkconfig) && die("Can't chkconfig --add $init_script: $!");

    $chkconfig = "$chkconfig_bin $init_script on";
    system($chkconfig) && die("Can't chkconfig $init_script on: $!");

    chdir $old;
}

1;
