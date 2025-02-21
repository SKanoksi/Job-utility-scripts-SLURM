#!/bin/bash
#SBATCH --partition=compute    # Partition
#SBATCH --nodes=2              # Number of nodes
#SBATCH --ntasks-per-node=32   # Number of tasks per node
#SBATCH --cpus-per-task=4      # Number of CPUs per task
#SBATCH -t 00:10:00            # Job runtime limit
#SBATCH -J HelloCPU            # Job name
#SBATCH -A ltxxxxxx            # Billing account

module purge
module load cpeCray/23.03

export PATH=/project/common/General/check_cpu_binding:${PATH}
export OMP_NUM_THREADS=${SLURM_CPUS_PER_TASK}
export CRAY_OMP_CHECK_AFFINITY=TRUE
#export OMP_AFFINITY_FORMAT="Thread: %.4n of %.4N (affinity: %.10A) [%.6P : %.12H]"
#export OMP_DISPLAY_AFFINITY=true

srun --cpus-per-task=${OMP_NUM_THREADS} hello.exe
#srun hello.exe

