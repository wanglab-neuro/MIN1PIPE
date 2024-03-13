#!/bin/bash
#SBATCH -t 10:00:00
#SBATCH -N 1 
#SBATCH -n 40
#SBATCH --gres=gpu:1
#SBATCH --constraint="high-capacity&12GB"
#SBATCH --mem=190G
#SBATCH --export=HDF5_USE_FILE_LOCKING=FALSE

# Same as run_minipipe, but copies the file to scratch space before running
module load mit/matlab/2021b

# Copy file to scratch space, in user / experiment specific directory
file_path=$1
scratch_path=/om/scratch/tmp/$USER/$(basename $(dirname $file_path))
mkdir -p scratch_file_path
rsync -Pavu $file_path $scratch_path/
scratch_file_path=$scratch_path/$(basename $file_path)

# Edit the line below if you cloned the code to your own directory 
cd /om/group/wanglab/code/MIN1PIPE_OM

echo "Running MIN1PIPE on $scratch_file_path"
matlab -nodesktop -nodisplay -r "run_min1pipe('$scratch_file_path', 'all'); exit;"

# Copy output files back to original location
rsync -Pavu $scratch_path/* $(dirname $file_path)/


