#!/usr/bin/perl
use strict;
use warnings;
use File::Basename;
use Cwd 'abs_path';
use Getopt::Long;

use lib dirname(abs_path($0)) . "/../lib";
use ProjectConfig qw(get_project_env create_sim_dir open_wave_after);


my $open_wave = 0;
GetOptions("wave" => \$open_wave);

# --- 1. SETUP ---
get_project_env();
my $sim_dir   = create_sim_dir();
my $work_path = "$sim_dir/work";

# --- 2. EXECUTION FLOW ---
# We call each stage as a distinct function
run_std_compile();
run_uart_compile($work_path);
run_optimization($work_path);
run_simulation($sim_dir);
open_wave_after($sim_dir) if $open_wave;

print "\n>>> ALL STAGES COMPLETE <<<\n";

# --- 3. FUNCTION DEFINITIONS ---

sub run_std_compile {
    print "\n--- STAGE: STD COMPILATION ---\n";
    my $std_script = "$ENV{REPO_ROOT}/scripts/compile/std_compile.pl";
    unless (do $std_script) {
        die "Error: Could not execute STD compile script: $@\n" if $@;
        die "Error: STD compile script failed.\n";
    }
}

sub run_uart_compile {
    my ($work) = @_;
    print "\n--- STAGE: UART COMPILATION ---\n";
    
    my $vlog_cmd = "vlog -work $work -sv -mfcu -L uvm " .
                   "+incdir+$ENV{UART_DESIGN_ROOT} " .
                   "+incdir+$ENV{UART_VERIF_ROOT}/env " .
                   "+incdir+$ENV{UART_VERIF_ROOT}/env/rx " .
                   "$ENV{UART_VERIF_ROOT}/env/rx/uart_rx_interface.sv " .
                   "$ENV{UART_DESIGN_ROOT}/*.sv " .
                   "$ENV{UART_VERIF_ROOT}/env/uart_env_pkg.sv " .
                   "$ENV{UART_VERIF_ROOT}/tests/uart_base_test.sv " .
                   "$ENV{UART_VERIF_ROOT}/tb/uart_tb_top.sv";

    system($vlog_cmd) == 0 or die "UART Compilation Failed!";
}

sub run_optimization {
    my ($work) = @_;
    print "\n--- STAGE: OPTIMIZATION (vopt) ---\n";

    # map uvm library
    my $vmap_cmd = "vmap uvm $ENV{QUESTASIM_HOME}/uvm-1.1d";
    system($vmap_cmd);
    
    # +acc gives us visibility into all signals for GTKWave/Waveforms
    my $vopt_cmd = "vopt -work $work -debug uart_tb_top -o opt_top -L uvm";
    
    system($vopt_cmd) == 0 or die "Optimization Failed!";
}

sub run_simulation {
    my ($results_dir) = @_;
    print "\n--- STAGE: SIMULATION (vsim) ---\n";
    
    my $test_name = "uart_base_test";
    my $log_file  = "$results_dir/sim.log";
    my $work_path = "$results_dir/work";
    my $vcd_file  = "$results_dir/waves.vcd"; # The output file

    # Added the vcd commands to the -do string
    my $vsim_cmd = "vsim -c " .
                   "-L uvm " .
                   "+UVM_TESTNAME=$test_name " .
                   "-do \"vmap work $work_path; " .
                   "vsim work.opt_top; " .
                   "vcd file $vcd_file; " . 
                   "vcd add -r /*; " . 
                   "run -all; quit\" " . 
                   "| tee $log_file";
    
    print "Executing Simulation and Dumping VCD...\n";
    
    if (system($vsim_cmd) == 0) {
        print "\n[PASS] Simulation finished.\n";
        print "Log: $log_file\n";
        print "VCD: $vcd_file\n";
    } else {
        die "Simulation failed!";
    }
}

