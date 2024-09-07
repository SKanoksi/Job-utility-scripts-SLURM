#!/bin/bash
#SBATCH -p gpu                 # Partition
#SBATCH -N 2                   # Number of nodes
#SBATCH --gpus-per-node=4      # Number of GPU card per node
#SBATCH --gpus-per-task=2      # Number of tasks per GPU
#SBATCH --cpus-per-gpu=16      # Number of CPUs per GPU
#SBATCH -t 00:10:00            # Job runtime limit
#SBATCH -J BindGPU_1           # Job name

# --gpus-per-task
# see https://cpe.ext.hpe.com/docs/latest/mpt/mpich/intro_mpi.html

srun bash -c \
"echo \"HelloWorld from task \${SLURM_PROCID} (locally \${SLURM_LOCALID} on \$(hostname)). I see gloal GPU ID \${SLURM_STEP_GPUS} <-> local GPU ID \${CUDA_VISIBLE_DEVICES}.\""

module purge
module load craype-x86-milan PrgEnv-nvhpc craype-accel-nvidia80

srun ./check_gpu.exe

