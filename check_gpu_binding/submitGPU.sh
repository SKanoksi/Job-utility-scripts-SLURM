#!/bin/bash
#SBATCH --partition=gpu        # Partition
#SBATCH --nodes=2              # Number of nodes
#SBATCH --gpus-per-node=4      # Number of GPUs per node
#SBATCH --ntasks-per-gpu=2     # Number of tasks per GPU
#SBATCH --cpus-per-task=8      # Number of CPUs per task
#SBATCH --ntasks=16            # Number ot tasks <-- *** Redundant due to Slurm ***
#SBATCH -t 00:10:00            # Job runtime limit
#SBATCH -J HelloGPU            # Job name
#SBATCH -A ltxxxxxx            # Billing account

module purge
module load craype-x86-milan PrgEnv-nvhpc craype-accel-nvidia80

export PATH=/project/common/General/check_gpu_binding:${PATH}

srun --cpus-per-task=${SLURM_CPUS_PER_TASK} check_gpu.exe
srun bash -c "echo \${SLURM_PROCID}: CUDA_VISIBLE_DEVICES = \${CUDA_VISIBLE_DEVICES}"

