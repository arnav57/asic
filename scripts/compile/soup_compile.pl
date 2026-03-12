#!/usr/bin/perl
use strict;
use warnings;
use File::Basename;
use Cwd 'abs_path';
use Getopt::Long;

use lib dirname(abs_path($0)) . "/../lib";
use ProjectConfig qw(get_project_env create_sim_dir open_wave_after);

# --- 1. SETUP ---
get_project_env();
my $sim_dir   = create_sim_dir();
my $work_path = "$sim_dir/work";

# --- 2. EXECUTION FLOW ---
run_std_compile();
run_uart_compile($work_path);
run_soup_compile($work_path);
run_optimization($work_path);
run_simulation($sim_dir);

# --- 3. FUNCTION DEFINITIONS ---

sub run_std_compile {
    print "\n--- STAGE: STD COMPILATION ---\n";
    # Windows/ModelSim fix: Explicitly create 'work' if it doesn't exist
    system("vlib work") unless -d "work";
    system("vlog -work work $ENV{STD_DESIGN_ROOT}/*.sv") == 0 or die "STD Compile Failed!";
}

sub run_uart_compile {
    my ($work) = @_;
    print "\n--- STAGE: UART COMPILATION ---\n";
    # Only compile the UART RTL for SOUP (don't need the UART tests/TB)
    system("vlog -work work -sv $ENV{UART_DESIGN_ROOT}/*.sv") == 0 or die "UART RTL Compile Failed!";
    # Still need the UART UVM Package for layering!
    system("vlog -work work -sv -L uvm +incdir+$ENV{UART_VERIF_ROOT}/env $ENV{UART_VERIF_ROOT}/env/uart_env_pkg.sv") == 0 or die "UART PKG Compile Failed!";
}

sub run_soup_compile {
    my ($work) = @_;
    print "\n--- STAGE: SOUP COMPILATION ---\n";
    
    my $vlog_cmd = "vlog -work work -sv -L uvm " .
                   "+incdir+$ENV{SOUP_DESIGN_ROOT} " .
                   "+incdir+$ENV{SOUP_VERIF_ROOT}/env " .
                   "+incdir+$ENV{SOUP_VERIF_ROOT}/tests " .
                   "$ENV{SOUP_VERIF_ROOT}/soup_interface.sv " .
                   "$ENV{SOUP_DESIGN_ROOT}/*.sv " .
                   "$ENV{SOUP_VERIF_ROOT}/env/soup_env_pkg.sv " .
                   "$ENV{SOUP_VERIF_ROOT}/tb/soup_tb_top.sv";

    system($vlog_cmd) == 0 or die "SOUP Compilation Failed!";
}

sub run_optimization {
    my ($work) = @_;
    print "\n--- STAGE: OPTIMIZATION (vopt) ---\n";
    # vopt is optional in some ModelSim versions, but good to have
    system("vopt -work work -debug soup_tb_top -o opt_top -L uvm") == 0 or die "Optimization Failed!";
}

sub run_simulation {
    my ($results_dir) = @_;
    print "\n--- STAGE: SIMULATION (vsim) ---\n";
    # Use opt_top and -c for command-line only
    my $vsim_cmd = "vsim -c -L uvm +UVM_TESTNAME=soup_base_test work.opt_top -do \"run -all; quit\"";
    system($vsim_cmd) == 0 or die "Simulation failed!";
}

print "\n>>> SOUP SIMULATION COMPLETE <<<\n";
