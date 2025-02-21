#!/bin/bash
#SBATCH -p compute-devel       # Partition
#SBATCH -N 1                   # Number of nodes
#SBATCH --ntasks-per-node=4    # Number of MPI processes per node
#SBATCH --cpus-per-task=8      # Number of CPUs per MPI process
#SBATCH -t 00:10:00            # Job runtime limit
#SBATCH -A ltxxxxxx            # Billing account 
#SBATCH -J HelloCPU            # Job name

module purge
module load cpeCray/23.03

export CRAY_OMP_CHECK_AFFINITY=TRUE
#export OMP_AFFINITY_FORMAT="Thread: %.4n of %.4N (affinity: %.10A) [%.6P : %.12H]"
#export OMP_DISPLAY_AFFINITY=true

#export OMP_PLACES=threads
export OMP_NUM_THREADS=${SLURM_CPUS_PER_TASK}

printf "\n\n--- srun with -c ---\n"
srun -c${OMP_NUM_THREADS} ./hello.exe | sort >& with_c.log

printf "\n\n--- srun without -c ---\n"
srun ./hello.exe | sort >& without_c.log


printf "\n\n--- srun without -c with omp_proc_bind=close ---\n"
export OMP_PROC_BIND=close
srun ./hello.exe | sort >& without_c_bind_close.log


printf "\n\n--- srun without -c with omp_proc_bind=spread ---\n"
export OMP_PROC_BIND=spread
srun ./hello.exe | sort >& without_c_bind_spread.log

