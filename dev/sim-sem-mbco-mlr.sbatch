#!/bin/bash
#SBATCH --job-name=sem-mbco-mlr
#SBATCH --partition=general
#SBATCH --account=2016507
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --time=08:00:00
#SBATCH --output=%x-%A_%a.out
# Pilot:  REPS=20 CHUNKS=1 sbatch --array=1-4 dev/sim-sem-mbco-mlr.sbatch
# Gate:   sbatch --array=1-320%20 dev/sim-sem-mbco-mlr.sbatch   (80 cells x 4 chunks)
# SLURM batch shells are non-login: `module` is undefined until lmod is sourced.
source /etc/profile.d/modules.sh
module load r/4.4.0-ytj2
command -v Rscript >/dev/null || { echo "Rscript not on PATH" >&2; exit 127; }
export R_LIBS="$HOME/Rlib-sem${R_LIBS:+:$R_LIBS}"
export SIM_INSTALLED=1 SIM_OUT="${SIM_OUT:-$HOME/projects/missingmed_sim/out-mlr}"
cd "$HOME/projects/missingmed_sim" || exit 1
Rscript dev/sim-sem-mbco-mlr-hopper.R
