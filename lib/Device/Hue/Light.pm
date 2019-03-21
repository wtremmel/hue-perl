package Device::Hue::Light;
{
  $Device::Hue::Light::VERSION = '0.4';
}

use common::sense;
use Class::Accessor;
use JSON::XS;
use Hash::Merge::Simple qw/ merge /;
use Data::Dumper;

use base qw(Class::Accessor);

__PACKAGE__->mk_accessors( qw / id hue _trx params data / );

sub max {
        my ($x, $y, $z) = (@_);
        return (($x > $y) && ($x > $z)) ? $x :
                ($y > $z) ? $y :
                $z;
}

sub min {
        my ($x, $y, $z) = (@_);
        return (($x < $y) && ($x < $z)) ? $x :
                ($y < $z) ? $y :
                $z;
}

sub rgbtohsl {
        # modified from http://mjijackson.com/2008/02/rgb-to-hsl-and-rgb-to-hsv-color-model-conversion-algorithms-in-javascript
        my $r = shift;
        my $g = shift;
        my $b = shift;
        my $fi = &max($r, $g, $b);

        $r /= 255; $g /= 255; $b /= 255;
        my $max = &max($r, $g, $b);
        my $min = &min($r, $g, $b);
        my $i = ($max + $min) /2;
        my $h = $i;
        my $s = $i;
        my $l = $i;

        if($max == $min) {
                $h = $s = 0; # no chroma
        } else {
                my $d = $max - $min;
                $s = ($l > 0.5) ? ($d / (2 - $max - $min)) :
                        ($d / ($max + $min));
                if ($max == $r) {
                        $h = ($g - $b) / $d + (($g < $b) ? 6 : 0);
                } elsif ($max == $g) {
                        $h = ($b - $r) / $d + 2;
                } elsif ($max == $b) {
                        $h = ($r - $g) / $d + 4;
                }
                $h /= 6;
        }

        $l = $fi;
        $s *= 255;
        $h *= 65535;

        # massage h, which has a non-linear response, to as close to colour
        # fidelity as possible. note that this fails for cyan, which comes
        # out somewhat like white.
        $h +=   ($h < 10923) ? (5462*($h/10923)) :
                ($h < 21846) ? (3755*($h/21845)) :
                ($h < 43691) ? (3414*($h/43691)) :
                ($h < 54613) ? (-5204*($h/54613)) :
                ($h < 59368) ? (-2023*($h/59368)) :
                0;

        return (int($h), int($s), int($l));
}

sub begin
{
        my ($self) = @_;

	$self->_trx(1);
	return $self;
}

sub commit
{
        my ($self) = @_;

	$self->_trx(0);

	my $r = $self->hue->put($self->hue->path_to('lights', $self->id, 'state'), $self->params);

	$self->params({});
	return $r;
}

sub in_transaction
{
	return (shift)->_trx;
}

sub merge_param
{
        my ($self, $param) = @_;
	$self->params(merge($self->params || {}, $param));
	return $self;
}

sub set_state
{
        my ($self, $param) = @_;

	if (exists $param->{'on'}) {
		$param->{'on'} = (defined $param->{'on'} && $param->{'on'}) ? JSON::XS::true : JSON::XS::false;
	}

	$self->merge_param($param);

	if ($self->_trx) {
	} else {
#		say Dumper($param);
		$self->commit;
#		say Dumper($r->data);
	}

	return $self;
}

sub get_state
{
  my ($self) = @_;
  my $r = $self->hue->get($self->hue->path_to('lights', $self->id));
  return $r->{'state'};
}

sub is_on
{
  return (shift)->get_state()->{'on'};
}
  
sub is_reachable
{
  return (shift)->get_state()->{'reachable'};
}

sub on
{
	return (shift)->set_state({ 'on' => 1 }); 
}

sub off
{
	return (shift)->set_state({ 'on' => 0 }); 
}

sub bri
{
	return (shift)->set_state({ 'bri' => int shift });
}

# 150-500
sub ct
{
	return (shift)->set_state({ 'ct' => int shift });
}

# 2000-6500
sub ct_k
{
	return (shift)->ct(1_000_000 / shift);
}

sub sat 
{
	return (shift)->set_state( { 'sat' => int shift });
}

sub hueval 
{
	return (shift)->set_state( { 'hue' => int shift });
}

sub rgb
{
  my ($self,$r,$g,$b) = @_;
  my ($h,$s,$l) = rgbtohsl($r,$g,$b);
  return $self->set_state({'hue'=>$h, 'sat'=>$s, 'bri'=>$l});
}

sub transitiontime
{
	return (shift)->merge_param({ 'transitiontime' => int shift });
}

sub name { return (shift)->data->{'name'}; }
sub type { return (shift)->data->{'type'}; }
sub modelid { return (shift)->data->{'modelid'}; }
sub swversion { return (shift)->data->{'swversion'}; }



1;

__END__

=pod

=head1 NAME

Device::Hue::Light

=head1 VERSION

version 0.4

=head1 AUTHOR

Alessandro Zummo <a.zummo@towertech.it>

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2013 by Alessandro Zummo.

This is free software, licensed under:

  The GNU General Public License, Version 2, June 1991

=cut
