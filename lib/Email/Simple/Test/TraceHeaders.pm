use strict;
use warnings;
package Email::Simple::Test::TraceHeaders;

use Carp ();
use Email::Date::Format ();
use Email::Simple;
use Email::Simple::Creator;
use Sub::Exporter::Util ();

use Sub::Exporter -setup => {
  exports => [ prev    => \'_build_prev' ],
  groups  => [ helpers => [ qw(prev) ] ],
};

# For now, we'll only generate one style of Received header: postfix
# It's what I encounter the most, and it's simple and straightforward.
# In the future, we'll be flexible, maybe. -- rjbs, 2009-06-19
my $POSTFIX_FMT = q{from %s (%s [%s]) by %s (Postfix) with ESMTP id %s }
                . q{for <%s>; %s};

sub _build_prev {
  my ($self) = @_;

  sub {
    my ($name) = @_;

    sub {
      my ($last) = @_;
      $last->{ $name };
    }
  }
}

sub create_email {
  my ($self, $arg) = @_;

  Carp::confess("no hops provided") unless $arg->{hops};

  my @received;
  my %last;
  for my $hop (@{ $arg->{hops} }) {
    my %hop = (%$hop);

    for my $key (keys %hop) {
      if (ref $hop->{$key} eq 'CODE') {
        $hop{ $key } = $hop{$key}->(\%last);
      }
    }

    push @received, sprintf $POSTFIX_FMT,
      $hop{from_helo},
      $hop{from_rdns},
      $hop{from_ip},
      $hop{by_name}, # by_ip someday?
      $hop{queue_id},
      $hop{env_to},
      (Email::Date::Format::email_gmdate($hop{time}) . ' (GMT)');

    %last = %hop;
  }

  my $email = Email::Simple->create(
    header => [
      (map {; Received => $_ } reverse @received),

      From => '"X. Ample" <xa@example.com>',
      To   => '"E. Xampe" <ex@example.org>',
    ],
    body    => "This is a test message.\n",
  );

  return $email;
}

1;
