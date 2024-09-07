#!/bin/bash
#SBATCH -p gpu                 # Partition
#SBATCH -N 2                   # Number of nodes
#SBATCH --gpus-per-node=4      # Number of GPU card per node
#SBATCH --cpus-per-gpu=16      # Number of CPUs per GPU
#SBATCH -t 00:10:00            # Job runtime limit
#SBATCH -J BindGPU_adv3        # Job name

# NUM_GPU_PER_MPI=1 --> Every MPI get 1 exclusive GPU
# NUM_GPU_PER_MPI=N --> Every MPI get (at most) N exclusive GPU

export NUM_GPU_PER_MPI=2       # Required by dist_gpu2mpi
export NUM_GPUS=$((${SLURM_JOB_NUM_NODES}*${SLURM_GPUS_PER_NODE}))
export NUM_MPI=$((${NUM_GPUS}/${NUM_GPU_PER_MPI}))                        # Floor by default
export NUM_CPUS_PER_MPI=$((${SLURM_CPUS_PER_GPU}*${NUM_GPUS}/${NUM_MPI})) # Floor by default
export OMP_NUM_THREADS=${NUM_CPUS_PER_MPI}
unset SLURM_CPUS_PER_GPU

# ---------------

module purge
module load craype-x86-milan PrgEnv-nvhpc craype-accel-nvidia80

srun -n${NUM_MPI} -c${NUM_CPUS_PER_MPI} ./dist_gpu2mpi ./check_gpu.exe

