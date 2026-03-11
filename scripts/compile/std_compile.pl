use strict;
use warnings;
use File::Basename;
use Cwd 'abs_path';

use lib dirname(abs_path($0)) . "/../lib";
use ProjectConfig qw(get_project_env create_sim_dir);

get_project_env();
my $sim_dir = create_sim_dir();

print "\n\n--- Compiling STD Library ---\n\n";

# We assume SIM_OUT_PATH is already set by the caller!
my $work_path = "$ENV{SIM_OUT_PATH}/work";

# Create the work lib if it doesn't exist
system("vlib $work_path") unless -d $work_path;

my $cmd = "vlog -work $work_path -sv " .
          "+incdir+$ENV{STD_DESIGN_ROOT} " .
          "$ENV{STD_DESIGN_ROOT}/*.sv";

if (system($cmd) != 0) { die "STD Compilation Failed!"; }

1; # Required so 'do' knows it succeeded