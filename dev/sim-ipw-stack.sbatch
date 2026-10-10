#!/bin/bash
#SBATCH --job-name=ipw-stack-cov
#SBATCH --partition=general
#SBATCH --account=2016507
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --time=02:00:00
#SBATCH --output=%x-%A_%a.out
# Pilot: ONLY_CELLS=1,40 REPS=20 sbatch --array=1-8 dev/sim-ipw-stack.sbatch
# Full:  sbatch --array=1-192%40 dev/sim-ipw-stack.sbatch   (48 cells x 4 chunks)
# SLURM batch shells are non-login: `module` is undefined until lmod is sourced.
source /etc/profile.d/modules.sh
module load r/4.4.0-ytj2
command -v Rscript >/dev/null || { echo "Rscript not on PATH" >&2; exit 127; }
export R_LIBS="$HOME/Rlib-sem${R_LIBS:+:$R_LIBS}"
export SIM_INSTALLED=1 SIM_OUT="${SIM_OUT:-$HOME/projects/missingmed_sim/out-ipw}"
cd "$HOME/projects/missingmed_sim" || exit 1
Rscript dev/sim-ipw-stack-hopper.R
