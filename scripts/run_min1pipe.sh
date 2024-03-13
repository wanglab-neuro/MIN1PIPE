#!/bin/bash
#SBATCH -t 05:00:00
#SBATCH -N 1 
#SBATCH -n 40
#SBATCH --gres=gpu:1
#SBATCH --constraint="high-capacity&12GB"
#SBATCH --mem=190G
#SBATCH --mail-user=$USER@mit.edu
#SBATCH --mail-type=BEGIN,END,FAIL,REQUEUE,TIME_LIMIT
#SBATCH -o ./logs/min1pipe-%j.out
#SBATCH --export=HDF5_USE_FILE_LOCKING=FALSE

module load mit/matlab/2021b

# Edit the line below if you cloned the code to your own directory 
cd /om/group/wanglab/code/MIN1PIPE_OM

file_path=$1
echo "Running MIN1PIPE on $file_path"
matlab -nodesktop -nodisplay -r "run_min1pipe('$file_path', 'all'); exit;"
