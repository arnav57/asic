#!/usr/bin/perl
use strict;
use warnings;
use File::Basename;
use Cwd 'abs_path';
use Getopt::Long;

use lib dirname(abs_path($0)) . "/../lib";
use ProjectConfig qw(get_project_env create_sim_dir get_module_paths);

# --- 1. PARSE ARGUMENTS ---
my $module_to_run = "soup"; # Default
my $test_name     = "";
my $wave          = 0;

GetOptions(
    "module=s" => \$module_to_run,
    "test=s"   => \$test_name,
    "wave"     => \$wave
);

# Default test names if none provided
if ($test_name eq "") {
    $test_name = ($module_to_run eq "soup") ? "soup_base_test" : "uart_loopback_test";
}

# --- 2. SETUP ENVIRONMENT ---
get_project_env();
my $sim_dir = create_sim_dir();
my $repo    = $ENV{REPO_ROOT};

# --- 3. THE BUILD STACK ---
# Define dependencies: soup depends on uart and std
my @stack = ("std", "uart", $module_to_run);

foreach my $mod (@stack) {
    print "\n>>> COMPILING MODULE: $mod <<<\n";
    my %paths = get_module_paths($mod);
    
    # Compile Design (if exists)
    if (-e "$paths{design}/$mod.f") {
        print "  Design Files...\n";
        system("vlog -work work -sv +incdir+$paths{design} -f $paths{design}/$mod.f") == 0 or die "Design compilation failed for $mod";
    }
    
    # Compile Verification (if exists)
    if (-e "$paths{verif}/${mod}_v.f") {
        print "  Verif Files...\n";
        system("vlog -work work -sv -L uvm +incdir+$paths{verif} -f $paths{verif}/${mod}_v.f") == 0 or die "Verif compilation failed for $mod";
    }
}

# --- 4. OPTIMIZE & RUN ---
print "\n>>> OPTIMIZING TOP <<<\n";
my $top = ($module_to_run eq "soup") ? "soup_tb_top" : "uart_tb_top";
system("vopt -debug $top -o opt_top -L uvm") == 0 or die "vopt failed!";

print "\n>>> STARTING SIMULATION: $test_name <<<\n";
my $vcd_file = "$sim_dir/waves.vcd";
my $vsim_cmd;

if ($wave) {
    # If wave is requested, add VCD dump commands to the -do string
    $vsim_cmd = "vsim -c -L uvm +UVM_TESTNAME=$test_name opt_top " .
                "-do \"vcd file $vcd_file; vcd add -r /*; run -all; quit\"";
} else {
    $vsim_cmd = "vsim -c -L uvm +UVM_TESTNAME=$test_name opt_top -do \"run -all; quit\"";
}

system($vsim_cmd) == 0 or die "Simulation failed!";

# --- 5. OPEN WAVEFORM ---
if ($wave) {
    print "\n>>> OPENING WAVEFORMS: $vcd_file <<<\n";
    # Call GTKWave in the background
    system("gtkwave $vcd_file &");
}

print "\n>>> SIMULATION COMPLETE. LOG: $sim_dir/sim.log <<<\n";
