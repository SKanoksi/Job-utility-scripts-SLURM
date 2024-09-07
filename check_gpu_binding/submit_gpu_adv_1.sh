#!/bin/bash
#SBATCH -p gpu                 # Partition
#SBATCH -N 2                   # Number of nodes
#SBATCH --gpus-per-node=2      # Number of GPU card per node
#SBATCH --cpus-per-gpu=16      # Number of CPUs per GPU
#SBATCH -t 00:10:00            # Job runtime limit
#SBATCH -J BindGPU_adv1        # Job name

# Every MPI can see every GPUs available on the node

export NUM_MPI=4
export NUM_GPUS=$((${SLURM_JOB_NUM_NODES}*${SLURM_GPUS_PER_NODE}))
export NUM_CPUS_PER_MPI=$((${SLURM_CPUS_PER_GPU}*${NUM_GPUS}/${NUM_MPI}))  # Floor by default
export OMP_NUM_THREADS=${NUM_CPUS_PER_MPI}
unset SLURM_CPUS_PER_GPU

# ---------------

module purge
module load craype-x86-milan PrgEnv-nvhpc craype-accel-nvidia80

srun -n${NUM_MPI} -c${NUM_CPUS_PER_MPI} ./check_gpu.exe

