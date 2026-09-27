# Job-utility-scripts-SLURM
Version: 1.1.0

Utility functions for 
- moving between job's working directories and checking logs
- checking software process and utilization of computing resources, granted for each SLURM job
- and others

### Installation:

A. Execute `. slurm_job_util.sh` or `source slurm_job_util.sh` before using, or \
B. Put `slurm_job_util.sh` it in `/etc/profile.d/`

### Available commands:

1. `tojob`\
   = change directory to the job's working directory.

2. `tailjob`\
   = tail StdOut/StdErr file of all currently running jobs

3. `myq`\
   = equivalent to "squeue --me" but with job index, intended to be used with 'tojob'

4. `cpu_usage <JobID> <NodeName>`\
   = display CPU utilization on all job's allocated nodes using top command --- an job step is added per invocation per node, [NodeName] is optional.

5. `gpu_usage <JobID>`\
   = display GPU utilization on all job's allocated nodes using nvidia-smi command --- an job step is added per invocation per node, [NodeName] is optional.

6. `ps_stat <JobID> <NodeName>`\
   = display the latest step's processes of a running job using ps command --- an job step is added per invocation per node, [NodeName] is optional. (Note: get PID from sstat so srun must be used)

7. `rss_usage <JobID> <NodeName>`\
   = display the total RSS currently used on all job's allocate nodes using ps+awk command --- an job step is added per invocation per node, [NodeName] is optional. (Note: get PID from sstat so srun must to be used)

8. `cpu_freq_usage <JobID>`\
   = display the CPU frequency of all job's allocated CPU cores using cpupower command --- an job step is added per invocation per node, [NodeName] is optional.
    
9. `get_timeleft`\
   = parse remaining runtime of a running job (in hours, minutes, seconds) for using with other scripts/software

10. `get_timelimit`\
   = parse wall time limit of a job (in hours, minutes, seconds) for using with other scripts/software

11. check_gpu_binding --> check_gpu.c\
   = simple c program to check NVIDIA GPU/CUDA resource binding before using the configuration to run an actual application software\
   = useful when 'srun --gpu-bind=verbose' or other similar options are unavailable.\
   (see check_gpu_binding/README and examples of job scripts ./check_gpu_binding/*.sh)

12. check_cpu_binding\
   = job scripts to check CPU affinity binding (and a simple HelloWorld program as an example)
   
