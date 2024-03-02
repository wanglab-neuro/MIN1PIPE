#!/bin/bash
#SBATCH -t 01:00:00
#SBATCH -N 1 
#SBATCH -n 50
#SBATCH --mem=5G
#SBATCH --export=HDF5_USE_FILE_LOCKING=FALSE

module load mit/matlab/2021a
cd /om/group/wanglab/code/MIN1PIPE_OM
matlab -nodisplay -r "run_min1pipe('./demo/demo_data.tif'); exit;"

