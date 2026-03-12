package ProjectConfig;
use strict;
use warnings;
use Cwd 'abs_path';
use File::Basename;
use File::Path qw(make_path);
use POSIX qw(strftime);
use Exporter 'import';

our @EXPORT_OK = qw(get_project_env create_sim_dir open_wave_after);

sub get_project_env {
    my $script_path = abs_path($0);
    my $repo_root = dirname(dirname(dirname($script_path)));
    
    my %env = (
        REPO_ROOT        => $repo_root,
        SIM_BASE         => "$repo_root/sim",
        STD_DESIGN_ROOT  => "$repo_root/design/std",
        UART_DESIGN_ROOT => "$repo_root/design/uart",
        UART_VERIF_ROOT  => "$repo_root/verif/uart",
    );
    
    foreach my $key (keys %env) { $ENV{$key} = $env{$key}; }
    return \%env;
}

sub create_sim_dir {
    my $timestamp = strftime("%Y_%m_%d_%H_%M_%S", localtime);
    my $sim_dir   = "$ENV{SIM_BASE}/run_$timestamp";

    if (!-d $sim_dir) {
        make_path($sim_dir) or die "Couldn't create $sim_dir: $!";
    }
    
    # Update the environment so the compiler knows where the 'work' lib is
    $ENV{SIM_OUT_PATH} = $sim_dir;

    # cd into the dir
    chdir("$sim_dir") or die "Cannot chdir to '$sim_dir':\n $!\n";

    return $sim_dir;
}

sub open_wave_after {
    my $sim_dir = shift;
    # this should be the wavedump dir
    my $open_wave_cmd = "gtkwave $sim_dir/waves.vcd";
    system($open_wave_cmd);
}

1;