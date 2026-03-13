#!/usr/bin/perl
use strict;
use warnings;
use File::Basename;
use Cwd 'abs_path';
use Getopt::Long;

use lib dirname(abs_path($0)) . "/../lib";
use ProjectConfig qw(get_project_env create_sim_dir get_module_paths open_wave_after);

# --- 1. PARSE ARGUMENTS ---
my $module_to_run = "soup"; # Default
my $test_name     = "";
my $top_module    = "";
my $wave          = 0;
my $help          = 0;
my $soup_loopback = 0;

GetOptions(
    "module=s"        => \$module_to_run,
    "test=s"          => \$test_name,
    "top=s"           => \$top_module,
    "wave"            => \$wave,
    "soup_loopback"   => \$soup_loopback,
    "help"            => \$help
);

if ($help) {
    print "Usage: perl $0 [options]\n";
    print "Options:\n";
    print "  --module <name>    Module to compile and run (default: soup)\n";
    print "  --test <name>      UVM test name to run\n";
    print "  --top <name>       Top-level module name (default: <module>_tb_top)\n";
    print "  --wave             Dump waveforms and open gtkwave after sim\n";
    print "  --soup_loopback    Enable SOUP PAD_TX to PAD_RX loopback in TB\n";
    print "  --help             Show this help message\n";
    exit(0);
}

# Default test names if none provided
if ($test_name eq "") {
    $test_name = ($module_to_run eq "soup") ? "soup_base_test" : "uart_loopback_test";
}

# --- 2. SETUP ENVIRONMENT ---
get_project_env();
my $sim_dir = create_sim_dir();
my $repo    = $ENV{REPO_ROOT};

# --- 3. THE BUILD STACK ---
# Define dependencies map
my %deps = (
    "std"  => [],
    "fifo" => [],
    "uart" => ["std"],
    "soup" => ["std", "fifo", "uart"]
);

# Function to flatten dependencies recursively
sub get_deps {
    my ($mod, $seen) = @_;
    return () if $seen->{$mod};
    $seen->{$mod} = 1;
    
    my @module_deps = @{$deps{$mod} || []};
    my @flat_deps;
    foreach my $d (@module_deps) {
        push(@flat_deps, get_deps($d, $seen));
    }
    push(@flat_deps, $mod);
    return @flat_deps;
}

my %seen;
my @stack = get_deps($module_to_run, \%seen);

print "\n>>> BUILD STACK FOR $module_to_run: " . join(", ", @stack) . " <<<\n";

foreach my $mod (@stack) {
    print "\n>>> COMPILING MODULE: $mod <<<\n";
    my %paths = get_module_paths($mod);
    
    # Compile Design (if exists)
    if (-e "$paths{design}/$mod.f") {
        print "  Design Files...\n";
        system("vlog -work work -sv -mfcu +incdir+$paths{design} -F $paths{design}/$mod.f") == 0 or die "Design compilation failed for $mod";
    }
    
    # Compile Verification (if exists)
    if (-e "$paths{verif}/${mod}_v.f") {
        print "  Verif Files...\n";
        system("vlog -work work -sv -mfcu -L uvm +incdir+$paths{verif} -F $paths{verif}/${mod}_v.f") == 0 or die "Verif compilation failed for $mod";
    }
}

# --- 4. OPTIMIZE & RUN ---
print "\n>>> OPTIMIZING TOP <<<\n";
# Try to find the top module in the verif file list
my $top = $top_module || "${module_to_run}_tb_top";
# Special case for uart which might use a different name if not following pattern
if ($module_to_run eq "uart" && !$top_module) { $top = "uart_tb_top"; }

system("vopt -debug $top -o opt_top -L uvm") == 0 or die "vopt failed for top $top!";

print "\n>>> STARTING SIMULATION: $test_name <<<\n";
my $vcd_file = "$sim_dir/waves.vcd";
my $log_file = "$sim_dir/sim.log";
my $vsim_cmd;

my $plusargs = "+UVM_TESTNAME=$test_name";
$plusargs .= " +WAVE" if $wave;
$plusargs .= " +SOUP_LOOPBACK" if $soup_loopback;

$vsim_cmd = "vsim -c -L uvm $plusargs opt_top -do \"run -all; quit\" | tee $log_file";

system($vsim_cmd) == 0 or die "Simulation failed!";

if ($wave) {
    open_wave_after($sim_dir);
}

print "\n>>> SIMULATION COMPLETE. LOG: $log_file <<<\n";
