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

matlab -nodesktop -nodisplay -r "run_min1pipe('./demo/demo_data.tif'); exit;"

# Job ID: 35582785
# Cluster: openmind7
# User/Group: prevosto/wanglab
# State: OUT_OF_MEMORY (exit code 0)
# Nodes: 1
# Cores per node: 40
# CPU Utilized: 03:25:14
# CPU Efficiency: 43.85% of 07:48:00 core-walltime
# Job Wall-clock time: 00:11:42
# Memory Utilized: 47.64 GB
# Memory Efficiency: 119.11% of 40.00 GB