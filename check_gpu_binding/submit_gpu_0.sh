#!/bin/bash
#SBATCH -p gpu                 # Partition
#SBATCH -N 2                   # Number of nodes
#SBATCH --gpus-per-node=4      # Number of GPU card per node
#SBATCH --ntasks-per-node=4    # Number of tasks per node
#SBATCH --cpus-per-gpu=16      # Number of CPUs per GPU
#SBATCH -t 00:10:00            # Job runtime limit
#SBATCH -A ltxxxxxx            # Billing account
#SBATCH -J BindGPU_0           # Job name

srun bash -c \
"echo \"HelloWorld from task \${SLURM_PROCID} (locally \${SLURM_LOCALID} on \$(hostname)). I see local GPU ID \${CUDA_VISIBLE_DEVICES}.\""


