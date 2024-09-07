#!/bin/bash
#SBATCH -p gpu                 # Partition
#SBATCH -N 2                   # Number of nodes
#SBATCH --gpus-per-node=2      # Number of GPU card per node
#SBATCH --cpus-per-gpu=16      # Number of MPI processes per node
#SBATCH -t 00:10:00            # Job runtime limit
#SBATCH -J HelloGPU            # Job name

srun bash -c \
"echo \"HelloWorld from task \${SLURM_PROCID} (locally \${SLURM_LOCALID} on \$(hostname)). I see gloal GPU ID \${SLURM_STEP_GPUS} <-> local GPU ID \${CUDA_VISIBLE_DEVICES}.\""


