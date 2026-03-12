package ProjectConfig;
use strict;
use warnings;
use Cwd 'abs_path';
use File::Basename;
use File::Path qw(make_path);
use POSIX qw(strftime);
use Exporter 'import';

our @EXPORT_OK = qw(get_project_env create_sim_dir get_module_paths open_wave_after);

sub get_project_env {
    my $script_path = abs_path($0);
    # Adjusting based on script depth (scripts/compile/...)
    my $repo_root = dirname(dirname(dirname($script_path)));
    
    $ENV{REPO_ROOT} = $repo_root;
    $ENV{SIM_BASE}  = "$repo_root/sim";
    
    # Set roots for known modules to support legacy scripts
    my @modules = qw(std uart soup);
    foreach my $mod (@modules) {
        my $upper_mod = uc($mod);
        $ENV{"${upper_mod}_DESIGN_ROOT"} = "$repo_root/design/$mod";
        $ENV{"${upper_mod}_VERIF_ROOT"}  = "$repo_root/verif/$mod";
    }
    
    return \%ENV;
}

# Automatically find design and verif roots for any module name
sub get_module_paths {
    my $module = shift;
    my $repo = $ENV{REPO_ROOT} || get_project_env()->{REPO_ROOT};
    
    return (
        design => "$repo/design/$module",
        verif  => "$repo/verif/$module"
    );
}

sub create_sim_dir {
    my $timestamp = strftime("%Y_%m_%d_%H_%M_%S", localtime);
    my $sim_dir   = "$ENV{SIM_BASE}/run_$timestamp";

    make_path($sim_dir) unless -d $sim_dir;
    $ENV{SIM_OUT_PATH} = $sim_dir;
    chdir("$sim_dir") or die "Cannot chdir to sim dir: $!";
    
    # Create the work library immediately if it doesn't exist
    system("vlib work") unless -d "work";
    
    # Map UVM library if QUESTASIM_HOME is set
    if ($ENV{QUESTASIM_HOME}) {
        system("vmap uvm $ENV{QUESTASIM_HOME}/uvm-1.1d > /dev/null");
    }
    
    return $sim_dir;
}

sub open_wave_after {
    my ($sim_dir) = @_;
    my $vcd_file = "$sim_dir/waves.vcd";
    if (-e $vcd_file) {
        print "\n>>> OPENING WAVEFORMS: $vcd_file <<<\n";
        system("gtkwave $vcd_file &");
    } else {
        warn "Warning: VCD file $vcd_file not found. Cannot open wave.\n";
    }
}

1;
