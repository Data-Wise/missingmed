#!/bin/bash
#SBATCH --job-name=ipw-mech
#SBATCH --partition=general
#SBATCH --account=2016507
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --time=01:00:00
#SBATCH --output=%x-%A_%a.out
# Pilot: ONLY_CELLS=1,100 REPS=20 sbatch --array=1-4 dev/sim-ipw-mech.sbatch
# Full:  sbatch --array=1-324%40 dev/sim-ipw-mech.sbatch   (162 cells x 2 chunks)
# SLURM batch shells are non-login: `module` is undefined until lmod is sourced.
source /etc/profile.d/modules.sh
module load r/4.4.0-ytj2
command -v Rscript >/dev/null || { echo "Rscript not on PATH" >&2; exit 127; }
export R_LIBS="$HOME/Rlib-sem${R_LIBS:+:$R_LIBS}"
export SIM_OUT="${SIM_OUT:-$HOME/projects/missingmed_sim/out-mech}"
cd "$HOME/projects/missingmed_sim" || exit 1
Rscript dev/sim-ipw-mech-hopper.R
