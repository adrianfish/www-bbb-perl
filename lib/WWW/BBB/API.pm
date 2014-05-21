package WWW::BBB::API;

use 5.008008;
use strict;
use warnings;

use URI;
use Digest::SHA qw(sha1_hex);
use XML::Simple;
use LWP::Simple;

our $VERSION = '0.03';

my %fields = (
    salt => undef,
    host => undef,
    path => 'bigbluebutton/api/'
);

my %api = (
    'join' => [qw/fullName meetingID password/],
    'create' => [qw/name meetingID attendeePW moderatorPW/],
    'getMeetingInfo' => [qw/meetingID password/]
);

sub new {

    my ($proto, %options) = @_;
    my $class = ref($proto) || $proto;
    my $self = {%fields};
    while (my ($key, $value) = each(%options)) {
        if (exists($fields{$key})) {
            $self->{$key} = $value if (defined $value);
        } else {
            die ref($class) . "::new: invalid option '$key'\n";
        }
    }

    # All the undef values in fields must be supplied by the caller
    foreach (keys(%fields)) {
        unless (defined $self->{$_}) {
            die ref($class) . "::new: must specify value for $_" 
        }
    }

    bless $self, $class;
    return $self;
}

sub join {

    my $self = shift;
    $self->cmd(&_subName);
    my %form;
    foreach (@{$api{$self->cmd}}) {
        $form{$_} = $self->$_;
    }
    my $uri = $self->_newUri;
    $uri->query_form(\%form);
    $form{checksum} = $self->_checksum($uri->query);
    $uri->query_form(\%form);
    return $uri->as_string;
}

sub create {

    my $self  = shift;
    $self->cmd(&_subName);
    my %form;
    foreach (@{$api{$self->cmd}}) {
        $form{$_} = $self->$_;
    }
    # a bug in 0.71 disable audio conference unless voiceBridge is not set
    $form{voiceBridge} = '00000' unless exists($form{voiceBridge});
    my $uri = $self->_newUri;
    $uri->query_form(\%form);
    $form{checksum} = $self->_checksum($uri->query);
    $uri->query_form(\%form);
    return $uri->as_string;
}

sub getMeetings {

    my $self = shift;
    $self->cmd(&_subName);
    my %form = (random => $self->_random_string(12));
	my $apiUrl = $self->_apiUrl(%form);
    my $xml = get($apiUrl);
    croak("getMeetings call on '" . $self->{host} . "' failed.") unless($xml);
    my $obj = XMLin($xml);
	return $obj;
}

sub getMeetingInfo {

    my $self = shift;
    my $options = shift;
    $self->cmd(&_subName);
    my %form;
    foreach (@{$api{$self->cmd}}) {
        $form{$_} = $options->{$_};
    }
    my $apiUrl = $self->_apiUrl(%form);
    my $xml = get($apiUrl);
    croak("getMeetingInfo call on '" . $self->{host} . "' failed.") unless ($xml);
    my $obj = XMLin($xml);
	return $obj;
}

sub getTotalParticipants {

    my $self = shift;

    my $meetings = $self->getMeetings->{meetings}->{meeting};

    my $count = 0;

    if (defined($meetings)) {
        if (ref($meetings) eq 'ARRAY') {
            foreach my $meeting (@$meetings) {
                my $info = $self->getMeetingInfo(
                    {
                        meetingID => $meeting->{meetingID},
                        password => $meeting->{moderatorPW}
                    } );
                $count += $info->{participantCount};
            }
        } else {
            my $info = $self->getMeetingInfo(
                {
                    meetingID => $meetings->{meetingID},
                    password => $meetings->{moderatorPW}
                } );
            $count += $info->{participantCount};
        }
    }

    return $count;
}

sub _apiUrl {

    my $self = shift;
    my %form = @_;
    my $uri = $self->_newUri;
    $uri->query_form(\%form);
    $form{checksum} = $self->_checksum($uri->query);
    $uri->query_form(\%form);
    return $uri->as_string;
}

sub _newUri {

    my $self = shift;
    my $uri = new URI();
    $uri->scheme('http');
    $uri->host($self->host);
    $uri->path($self->path . $self->cmd);
    return $uri;
}

sub _checksum {

    my $self = shift;
    my $qs = shift;

    my $salt = $self->salt;
    my $cmd = $self->cmd;

    my $checksum_string = $cmd . $qs . $salt;
    return sha1_hex($checksum_string);
}

# Gets the name of the calling subroutine.
sub _subName { (split(/::/,(caller(1))[3]))[-1] }

sub _random_string {

    my $self	= shift;
    my $length	= shift;
    my @chars=('a'..'z','A'..'Z','0'..'9');
    my $random_string;
    foreach (1..$length) {
        $random_string.=$chars[rand @chars];
    }
    return $random_string;
}

sub cmd { my $s = shift; if (@_) { $s->{cmd} = shift; } return $s->{cmd}; }
sub salt { my $s = shift; if (@_) { $s->{salt} = shift; } return $s->{salt}; }
sub host { my $s = shift; if (@_) { $s->{host} = shift; } return $s->{host}; }
sub path { my $s = shift; if (@_) { $s->{path} = shift; } return $s->{path}; }
sub fullName { my $s = shift; if (@_) { $s->{fullName} = shift; } return $s->{fullName}; }
sub meetingID { my $s = shift; if (@_) { $s->{meetingID} = shift; } return $s->{meetingID}; }
sub password { my $s = shift; if (@_) { $s->{password} = shift; } return $s->{password}; }
sub name { my $s = shift; if (@_) { $s->{name} = shift; } return $s->{name}; }
sub attendeePW { my $s = shift; if (@_) { $s->{attendeePW} = shift; } return $s->{attendeePW}; }
sub moderatorPW { my $s = shift; if (@_) { $s->{moderatorPW} = shift; } return $s->{moderatorPW}; }

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

WWW::BBB::API - Perl interface to BigBlueButton API system

=head1 SYNOPSIS

  use WWW::BBB::API;

  my $bbb = new WWW::BBB::API(salt => $salt, host => $host);

  # Get all the meetings on this server
  my $meetings = $bbb->getMeetings;

  # Get the total number of participants across all meetings
  my $totalParticipants = $bbb->getTotalParticipants;

  my $info = $bbb->getMeetingInfo( {
        meetingID => 'MEETINGID',
        password => 'MODERATOR PASSWORD'
    } );

=head1 DESCRIPTION

=head1 AUTHORS

Emiliano Bruni, E<lt>info@ebruni.itE<gt>

Adrian Fish, E<lt>a.fish@lancaster.ac.ukE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2010 by Emiliano Bruni

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.


=cut
