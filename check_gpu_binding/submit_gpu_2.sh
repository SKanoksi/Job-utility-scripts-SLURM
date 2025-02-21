#!/bin/bash
#SBATCH -p gpu                 # Partition
#SBATCH -N 1                   # Number of nodes
#SBATCH --gpus-per-node=2      # Number of GPU card per node
#SBATCH --ntasks-per-gpu=2     # Number of tasks per GPU
#SBATCH --cpus-per-gpu=16      # Number of CPUs per GPU
#SBATCH -t 00:10:00            # Job runtime limit
#SBATCH -A ltxxxxxx            # Billing account 
#SBATCH -J BindGPU_2           # Job name

# --ntasks-per-gpu 

srun bash -c \
"echo \"HelloWorld from task \${SLURM_PROCID} (locally \${SLURM_LOCALID} on \$(hostname)). I see local GPU ID \${CUDA_VISIBLE_DEVICES}.\""

module purge
module load craype-x86-milan PrgEnv-nvhpc craype-accel-nvidia80

srun -c 8 ./check_gpu.exe 

