# Job-utility-scripts-SLURM
Simple utility bash scripts for checking SLURM jobs

Version: 0.0.1

1. myq\
   = equivalent to "squeue --me" but with job index, intended to be used with 'tojob'\
   Usage: myq

2. tojob\
   = change directory to the job's working directory --- this script needed to be sourced.\
   Usage: . tojob [job-id]  or  . tojob -n [job-index]

3. tailjob\
   = tail StdOut file of all currently running jobs\
   Usage: tailjob  or  tailjob [job-id]

4. cpu_usage\
   = display CPU utilization of a running job on an allocated node by using top command --- an job step is added per invocation.\
   Usage: cpu_usage [job-id] [single-alloc-node] [extra-srun-options]

5. gpu_usage\
   = display GPU utilization of a running job on an allocated node by using nvidia-smi command --- an job step is added per invocation. 
   Occasionally, --gpus=Num is needed to be added (as an extra-srun-options) to specify the exact number of GPUs available on the node.\
   Usage: gpu_usage [job-id] [single-alloc-node] [extra-srun-options]

6. get_timeleft\
   = parse remaining runtime of a running job (in hours, minutes, seconds) for using with other scripts/software\
   (see get_timeleft --help)

7. get_timelimit\
   = parse wall time limit of a job (in hours, minutes, seconds) for using with other scripts/software\
   (see get_timelimit --help)

Installation:
- Put these files in a directory included in the PATH environment variable.   
