package DPP::LogHelper;
use common::sense;
use Term::ANSIColor qw(color colorstrip);


sub _get_color_by_level {
    my $self = shift;
    my $level = shift;
    my $color_map = {
        debug => 'blue',
        error => 'bold red',
        warning => 'bold yellow',
        info => 'green',
        notice => 'cyan',
    };
    my $color;
    if (defined( $color_map->{$level} )) {
        $color = $color_map->{$level}
    } else {
        $color= 'green';
    }
    return color($color) . $level . color('reset');
}
sub _log_helper_timestamp() {
    my $self = shift;
    my %a = @_;
    my $out;
    my $multiline_mark = '';
    foreach( split(/\n/,$a{'message'}) ) {
        if ( $cfg->{'log'}{'ansicolor'} ) {
            $out .= color('bright_green') .  strftime('%Y-%m-%dT%H:%M:%S%z',localtime(time)) . color('reset') . ' ' .  &_get_color_by_level($a{'level'}) . ': ' . $multiline_mark . $_ . "\n";
        } else {
            $out .= strftime('%Y-%m-%dT%H:%M:%S%z',localtime(time)) . ' ' . $a{'level'} . ': ' . $multiline_mark . colorstrip($_) . "\n";
        }
        $multiline_mark = '.  '
    }
    return $out
}
