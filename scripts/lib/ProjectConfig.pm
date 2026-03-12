package ProjectConfig;
use strict;
use warnings;
use Cwd 'abs_path';
use File::Basename;
use File::Path qw(make_path);
use POSIX qw(strftime);
use Exporter 'import';

our @EXPORT_OK = qw(get_project_env create_sim_dir get_module_paths);

sub get_project_env {
    my $script_path = abs_path($0);
    # Adjusting based on script depth (scripts/compile/...)
    my $repo_root = dirname(dirname(dirname($script_path)));
    
    my %env = (
        REPO_ROOT => $repo_root,
        SIM_BASE  => "$repo_root/sim",
    );
    
    foreach my $key (keys %env) { $ENV{$key} = $env{$key}; }
    return \%env;
}

# Automatically find design and verif roots for any module name
sub get_module_paths {
    my $module = shift;
    my $repo = $ENV{REPO_ROOT};
    
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
    chdir("$sim_dir") or die "Cannot chdir to sim dir!";
    
    # Create the work library immediately
    system("vlib work");
    return $sim_dir;
}

1;
