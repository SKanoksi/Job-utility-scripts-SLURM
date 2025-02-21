#!/bin/bash
#SBATCH -p compute             # Partition
#SBATCH -N 1                   # Number of nodes
#SBATCH --ntasks-per-node=2    # Number of MPI processes per node
#SBATCH --cpus-per-task=4      # Number of CPUs per MPI process
#SBATCH -t 00:10:00            # Job runtime limit
#SBATCH -A ltxxxxxx            # Billing account 
#SBATCH -J HelloCPU            # Job name

module purge
module load cpeCray/23.03

export OMP_NUM_THREADS=${SLURM_CPUS_PER_TASK}

srun -c${OMP_NUM_THREADS} ./hello.exe


