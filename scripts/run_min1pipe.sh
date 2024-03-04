#!/bin/bash
#SBATCH -t 01:00:00
#SBATCH -N 1 
#SBATCH -n 40
#SBATCH --gres=gpu:1
#SBATCH --constraint=high-capacity
#SBATCH --mem=80G
#SBATCH --export=HDF5_USE_FILE_LOCKING=FALSE

module load mit/matlab/2021b
cd /om/group/wanglab/code/MIN1PIPE_OM

file_path=$1
matlab -nodesktop -nodisplay -r "run_min1pipe('$file_path', 'true'); exit;"