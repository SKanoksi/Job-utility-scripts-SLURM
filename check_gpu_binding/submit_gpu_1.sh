#!/bin/bash
#SBATCH -p gpu                 # Partition
#SBATCH -N 2                   # Number of nodes
#SBATCH --gpus-per-node=2      # Number of GPU card per node
#SBATCH --ntasks-per-node=2    # Number of tasks per node
#SBATCH --cpus-per-gpu=16      # Number of CPUs per GPU
#SBATCH -t 00:10:00            # Job runtime limit
#SBATCH -J BindGPU_1           # Job name

# --ntasks-per-node
# = Every MPI can see every GPUs available on the node

srun bash -c \
"echo \"HelloWorld from task \${SLURM_PROCID} (locally \${SLURM_LOCALID} on \$(hostname)). I see gloal GPU ID \${SLURM_STEP_GPUS} <-> local GPU ID \${CUDA_VISIBLE_DEVICES}.\""

module purge
module load craype-x86-milan PrgEnv-nvhpc craype-accel-nvidia80

srun ./check_gpu.exe

