#!/bin/bash
#SBATCH -t 10:00:00
#SBATCH -N 1 
#SBATCH -n 40
#SBATCH --gres=gpu:1
#SBATCH --constraint=high-capacity
#SBATCH --mem=190G
#SBATCH --export=HDF5_USE_FILE_LOCKING=FALSE

module load mit/matlab/2021b

# Copy file to scratch space
mkdir -p /om/scratch/tmp/$USER
rsync -Pavu $file_path /om/scratch/tmp/$USER/

# Edit the line below if you cloned the code to your own directory 
cd /om/user/nitsan/code/MIN1PIPE_OM

file_path=$1
echo "Running MIN1PIPE on $file_path"
matlab -nodesktop -nodisplay -r "run_min1pipe('$file_path', 'all'); exit;"
