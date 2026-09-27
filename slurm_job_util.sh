# ----------------------------------------------------------
#
#  slurm_job_util.sh version 1.1.0
#
#  Various extra BASH commands for SLURM jobs 
#
#  Copyright (c) 2026, Somrath Kanoksirirath.
#  All rights reserved under BSD 3-clause license.
# ----------------------------------------------------------
#
#  *** Hardware utilization ***
#  1)  gpu_usage <jobid> [nodename]
#  2)  cpu_usage <jobid> [nodename]
#  3)    ps_stat <jobid> [nodename]     <-- srun must be used
#  4)  rss_usage <jobid> [nodename]     <-- srun must be used 
#  5)  cpu_freq_usage <jobid> [nodename]
#
#  WARNING: Don’t query too often, since they interferes with your main workload and steal computing time !!!
#
#  *** Other utility tools ***
#  1)  tojob [jobid]
#  2)  tailjob [jobid]
#  3)  myq
#
# ----------------------------------------------------------


function __job_loop_over_node(){
  local QUERY_SET_COUNT="0"
  while read -r line
  do
    QUERY_SET_COUNT=$((${QUERY_SET_COUNT}+1))

    local JOB_NODELIST=${line#*Nodes=}
    JOB_NODELIST=${JOB_NODELIST%% CPU_IDs=*}
    local JOB_NODE_CPU_IDS=${line#*CPU_IDs=}
    JOB_NODE_CPU_IDS=${JOB_NODE_CPU_IDS%% Mem=*}
    local JOB_NODE_GPU_COUNT=${line%%(IDX*}
    JOB_NODE_GPU_COUNT=${JOB_NODE_GPU_COUNT##*GRES=gpu:*:}

    JOB_NODELIST_ARRAY=$(scontrol show hostnames ${JOB_NODELIST})
    for JOB_NODELIST_ITEM in ${JOB_NODELIST_ARRAY}
    do
      ${2} "${1}" "${JOB_NODELIST_ITEM}" "${JOB_NODE_CPU_IDS}" "${JOB_NODE_GPU_COUNT}"
    done
    sleep 1
  done < <(scontrol -d --quiet show job ${1} | grep -A 30 "${UID}" | grep 'CPU_IDs')

  if [ ${QUERY_SET_COUNT} -eq 0 ]; then
    echo "ERROR: Invalid JobID was specified. Is your job running?"
  fi
}


function gpu_usage(){
  if [ -z "${1}" ] || ! [[ ${1} =~ ^[1-9][0-9_]*$ ]]; then
    echo "Usage: gpu_usage <your-jobid> [one-of-the-job-nodename]"
    return 1
  fi
  local SINGLE_NODE_NAME=
  if [ -n "${2}" ]; then
    if [ "${2::8}" = "lanta-g-" ]; then
      SINGLE_NODE_NAME="${2}"
    else
      echo "ERROR:: Incorrect nodename, must start with 'lanta-g-', omit to query all"
      return 1
    fi
  fi

  function srun_nvidia_smi_query(){
    if [ -n "${SINGLE_NODE_NAME}" ] && [ "${SINGLE_NODE_NAME}" != "${2}" ]; then
      return
    fi
    if [ "${2::8}" != "lanta-g-" ]; then
      echo "ERROR:: No GPUs. The job node (${2}) is NOT 'lanta-g-xxx'."
      return
    fi
    echo ""
    echo "######################################"
    echo "          ${4} GPUs on ${2}"
    echo "######################################"
    srun --input none --jobid=${1} -w ${2} -N1 -n1 -c1 -u --overlap nvidia-smi
    RTC=$?
    if [ ${RTC} -ne 0 ]; then
      printf "\nUsage: gpu_usage <your-jobid> [one-of-the-job-nodename]\n\n"
    fi    
    echo ""
  }

  __job_loop_over_node ${1} srun_nvidia_smi_query
}


function cpu_usage(){
  if [ -z "${1}" ] || ! [[ ${1} =~ ^[1-9][0-9_]*$ ]]; then
    echo "Usage: cpu_usage <your-jobid> [one-of-the-job-nodename]"
    return 1
  fi
  local SINGLE_NODE_NAME=
  if [ -n "${2}" ]; then
    if [ "${2::6}" = "lanta-" ]; then
      SINGLE_NODE_NAME="${2}"
    else
      echo "ERROR:: Incorrect nodename, must start with 'lanta-', omit to query all"
      return 1
    fi
  fi

  function srun_top_query(){
    if [ -n "${SINGLE_NODE_NAME}" ] && [ "${SINGLE_NODE_NAME}" != "${2}" ]; then
      return
    fi
    echo ""
    echo "######################################"
    echo "          top on ${2}"
    echo "######################################"
    srun --input none --jobid=${1} -w ${2} -N1 -c1 --ntasks-per-node=1 -u --overlap top -b -n1 -Eg -u ${USER}
    RTC=$?
    if [ ${RTC} -ne 0 ]; then
      printf "\nUsage: cpu_usage <your-jobid> [one-of-the-job-nodename]\n\n"
    fi
    echo ""
  }

  __job_loop_over_node ${1} srun_top_query
}


function ps_stat(){
  if [ -z "${1}" ] || ! [[ ${1} =~ ^[1-9][0-9_]*$ ]]; then
    echo "Usage: ps_stat <your-jobid> [one-of-the-job-nodename]"
    return 1
  fi
  local SINGLE_NODE_NAME=
  if [ -n "${2}" ]; then
    if [ "${2::6}" = "lanta-" ]; then
      SINGLE_NODE_NAME="${2}"
    else
      echo "ERROR:: Incorrect nodename, must start with 'lanta-', omit to query all"
      return 1
    fi
  fi

  function srun_ps_query(){
    if [ -n "${SINGLE_NODE_NAME}" ] && [ "${SINGLE_NODE_NAME}" != "${2}" ]; then
      return
    fi
    echo ""
    echo "######################################"
    echo "          ps on ${2}"
    echo "######################################"
    local JOB_NODE_PIDS=$(sstat -j ${1} -i -n -o pids%2000 | grep "${2}" | awk '{list = $3} END {print list}')
    if [ -n "${JOB_NODE_PIDS}" ]; then
      srun --input none --jobid=${1} -w ${2} -N1 -c1 --ntasks-per-node=1 -u --overlap ps -p ${JOB_NODE_PIDS} -o user,pid,thcount,numa,pcpu,rss,vsz,start_time,etime,state,comm | numfmt --header --from-unit=1024 --to=iec-i --field 6,7 --padding 6
      RTC=$?
      if [ ${RTC} -ne 0 ]; then
        printf "\nUsage: ps_stat <your-jobid> [one-of-the-job-nodename]\n\n"
      fi
      echo ""
    else
      printf "\nUsage: ps_stat <your-jobid> [one-of-the-job-nodename]\n\n"
      echo "ERROR:: Cannot get the job's PIDs -- Please check that 1) The JobID and its nodename are correct 2) srun is used in the job script 3) The job is running"
    fi
  }

  __job_loop_over_node ${1} srun_ps_query
}

function rss_usage(){
  if [ -z "${1}" ] || ! [[ ${1} =~ ^[1-9][0-9_]*$ ]]; then
    echo "Usage: rss_usage <your-jobid> [one-of-the-job-nodename]"
    return 1
  fi
  local SINGLE_NODE_NAME=
  if [ -n "${2}" ]; then
    if [ "${2::6}" = "lanta-" ]; then
      SINGLE_NODE_NAME="${2}"
    else
      echo "ERROR:: Incorrect nodename, must start with 'lanta-', omit to query all"
      return 1
    fi
  fi

  function srun_rss_query(){
    if [ -n "${SINGLE_NODE_NAME}" ] && [ "${SINGLE_NODE_NAME}" != "${2}" ]; then
      return
    fi
    local JOB_NODE_PIDS=$(sstat -j ${1} -i -n -o pids%2000 | grep "${2}" | awk '{list = $3} END {print list}')
    if [ -n "${JOB_NODE_PIDS}" ]; then
      echo ""
      echo "Total RSS of all user's processes inside JobID ${1} on ${2}"
      srun --input none --jobid=${1} -w ${2} -N1 -c1 --ntasks-per-node=1 -u --overlap ps -p ${JOB_NODE_PIDS} -o rss= | awk '{sum+=$1} END {printf "--> %d KiB = %.2f MiB = %.2f GiB \n", sum, sum/1024, sum/1024/1024}';
      RTC=$?
      if [ ${RTC} -ne 0 ]; then
        printf "\nUsage: rss_usage <your-jobid> [one-of-the-job-nodename]\n\n"
      fi
      echo ""
    else
      printf "\nUsage: rss_usage <your-jobid> [one-of-the-job-nodename]\n\n"
      echo "ERROR:: Cannot get the job's PIDs -- Please check that 1) The JobID and its nodename are correct 2) srun is used in the job script 3) The job is running"
    fi
  }

  __job_loop_over_node ${1} srun_rss_query
}


function cpu_freq_usage(){
  if [ -z "${1}" ] || ! [[ ${1} =~ ^[1-9][0-9_]*$ ]]; then
    echo "Usage: cpu_freq_usage <your-jobid> [one-of-the-job-nodename]"
    return 1
  fi
  local SINGLE_NODE_NAME=
  if [ -n "${2}" ]; then
    if [ "${2::6}" = "lanta-" ]; then
      SINGLE_NODE_NAME="${2}"
    else
      echo "ERROR:: Incorrect nodename, must start with 'lanta-', omit to query all"
      return 1
    fi
  fi

  function srun_cpu_power_query(){
    if [ -n "${SINGLE_NODE_NAME}" ] && [ "${SINGLE_NODE_NAME}" != "${2}" ]; then
      return
    fi
    echo "######################################"
    echo " CPUID_[${3}] on ${2}"
    echo "######################################"
    srun --input none --jobid=${1} -w ${2} -N1 -c1 --ntasks-per-node=1 -u --overlap cpupower --cpu ${3} frequency-info -f  | grep 'current CPU frequency' | awk '{printf "%3d:  %.3f MHz\n", NR, $4/1000 ;sum+=$4;count++} END  {if (count>0) printf "\nAveraged CPU frequency = %.3f GHz", sum/count/1000000}'
    printf " on %s\n\n" ${2}
  }

  __job_loop_over_node ${1} srun_cpu_power_query
}


function myq(){
  squeue --me ${@:1} | awk 'NR>1 { $0 = gensub("^ {5}", "", 1, $0); printf " %-3d %s\n", NR-1, $0; } NR==1 { print; }'
}


function tojob(){

  local GOTO_JOBID=""
  local GOTO_INDEX=""
  local PREFIX_DIRKEY="/lustrefs/"

  while [ $# -gt 0 ]; do
    case "${1}" in
      -i)
        if [ -n "${2}" ] && [[ ${2} =~ ^[0-9]+$ ]] ; then
          GOTO_INDEX=${2}
          shift
        else
          echo "ERROR:: Option -i requires a non-zero integer."
          return 1
        fi
      ;;
      -i*)
        local TEMP=${1#-i}
        if [ -n "${TEMP}" ] && [[ ${TEMP} =~ ^[0-9]+$ ]] ; then
          GOTO_INDEX=${TEMP}
        else
          echo "ERROR:: Option -i requires a non-zero integer."
          return 1
        fi
      ;;
      -h | -H | -help | --help)
        printf "\nUsage: tojob [SLURM-JOB-ID]\n"
        printf "  Move to the SLURM job submitted/working directory\n"
	printf "\nUsage: tojob\n"
	printf "  Move to the interactively selected SLURM job directory\n"
	printf "\nUsage: tojob -i <JOB-INDEX>\n"
        printf "  Move to the dir of the active <JOB-INDEX> in 'myq'\n\n"
	return 0
      ;;
      *)
        GOTO_JOBID=${1}
      ;;
    esac
    shift
  done


  if [ -n "${GOTO_JOBID}" ]; then
    if [ -n "${GOTO_INDEX}" ]; then
      echo "WARNING:: JobID is specified together with -i option. Option -i will be ignored."
      GOTO_INDEX=""
    fi
    if ! [[ ${GOTO_JOBID} =~ ^[1-9][0-9_]*$ ]] ; then
      echo "ERROR:: JobID needs to be a non-zero integer."
      return 1
    fi
  else
    if [ -z "${GOTO_INDEX}" ]; then
      printf " CHOICE  --- MYQUEUE ---\n"
      local INDEX=0
      local INPUT_INDEX=0
      while read -r line
      do
        INDEX=$((${INDEX}+1))
        printf " %-5s   %-s\n" "[${INDEX}]" "${line}"
      done < <(squeue --me --noheader)
      if [ ${INDEX} -eq 0 ]; then
        echo "You have no active jobs. Specify JobID explicitly."
        return 0
      else
        echo " [Else]  Quit"
        echo ""
        printf "Select: "
        read INPUT_INDEX
      fi

      if [[ ${INPUT_INDEX} =~ ^[0-9]+$ ]]; then
        if [ ${INPUT_INDEX} -le ${INDEX} ]; then
          GOTO_INDEX="${INPUT_INDEX}"
	  echo "---"
        else
          echo "ERROR:: Invalid job index, Out-of-Range."
          return 0
        fi
      else
        return 0
      fi
    fi

    local INDEX=0
    while read -r line
    do
      INDEX=$((${INDEX}+1))
      if [ ${INDEX} -eq ${GOTO_INDEX} ]; then
        GOTO_JOBID=${line%% *}
        break
      fi
    done < <(squeue --me --noheader --format=%i)

    if [ -z "${GOTO_JOBID}" ]; then
      echo "ERROR:: Invalid job index, Out-of-Range."
      return 1
    fi
  fi

  GOTO_DIR=$(scontrol --quiet show job ${GOTO_JOBID} | grep 'WorkDir=')
  GOTO_DIR=${GOTO_DIR#*WorkDir=}
  if [ -z "${GOTO_DIR}" ]; then
    GOTO_DIR=$(sacct -j ${GOTO_JOBID} --format=workdir%1000 | grep ${PREFIX_DIRKEY})
    GOTO_DIR=$(echo ${GOTO_DIR##*${PREFIX_DIRKEY}} | tr -d ' ')
    if [ -n "${GOTO_DIR}" ]; then
      GOTO_DIR=${PREFIX_DIRKEY}${GOTO_DIR}
    else
      echo " Cannot find the record of JobID ${GOTO_JOBID}. Your job may be too old."
      return 0
    fi
  fi

  if [ -d "${GOTO_DIR}" ] && [ -x "${GOTO_DIR}" ] ; then
    cd ${GOTO_DIR}
    echo " SLURM submitted/working directory of JobID ${GOTO_JOBID} "
  else
    echo " Please check your JobID."
    echo " If it is correct, then the directory is no longer exist or you don't have its execute/search permission."
    return 0
  fi
}


function tailjob(){

  local SINGLE_JOBID=""
  local NUM_LINE=""
  local STREAM="StdOut"

  while [ $# -gt 0 ]; do
    case "${1}" in
      -n)
	if [ -n "${2}" ] && [[ ${2} =~ ^[0-9]+$ ]] ; then
	  NUM_LINE=${2}
          shift
	else
	  echo "ERROR:: Option -n requires a non-zero integer."
          return 1
        fi
      ;;
      -n*)
        local TEMP=${1#-n}
        if [ -n "${TEMP}" ] && [[ ${TEMP} =~ ^[0-9]+$ ]] ; then
          NUM_LINE=${TEMP}
        else
          echo "ERROR:: Option -n requires a non-zero integer."
          return 1
        fi
      ;;
      -e | --err)
	STREAM="StdErr"
      ;;
      -h | -H | -help | --help)
        printf "\nUsage: tailjob [-Opt0,...] [A-SLURM-JOB-ID]\n"
        printf "  tail the logfile of your running jobs\n\n"
	printf "Options:\n"
	printf "  -n <num>   number of lines being tailed\n"
	printf "  -e,--err    get StdErr instead of StdOut\n"
	printf "  -h,--help  show this help then exit\n\n"
        return 0
      ;;
      *)
        SINGLE_JOBID=${1}
      ;;
    esac
    shift
  done

  if [ -n "${SINGLE_JOBID}" ]; then
    if ! [[ ${SINGLE_JOBID} =~ ^[1-9][0-9_]*$ ]] ; then
      echo "ERROR:: JobID needs to be a non-zero integer."
      return 1
    fi 
    CHECKJOB=$(squeue --me --long | grep "${SINGLE_JOBID}")
    if [ -z "${CHECKJOB}" ]; then
      echo "The specified JobID is invalid. Is your job still active?"
      echo "Try \"tojob ${SINGLE_JOBID}\" to directly visit its submitted/working direcitory."
      return 0
    else
      if [ -z "${NUM_LINE}" ]; then
        NUM_LINE=30
      fi
    fi
  else
    if [ -z "${NUM_LINE}" ]; then
      NUM_LINE=10
    fi
  fi

  local color_show=$(tput setaf 10)
  local color_hide=$(tput setaf 8)
  local color_orig=$(tput sgr0)

  function displaylog()
  {
    local JOBID=${1}
    local JOBINFO=$(scontrol --quiet show job ${JOBID})
    local LOGFILE=$(echo "${JOBINFO}" | grep "${STREAM}=")
    LOGFILE=${LOGFILE#*${STREAM}=}
    local JOBNAME=$(echo "${JOBINFO}" | grep 'JobName=')
    JOBNAME=${JOBNAME#*JobName=}

    if [ -n "${LOGFILE}" ]; then
      printf "\n%s\n" "${color_show}vvv '${JOBNAME}' (JobID: ${JOBID}) vvv${color_orig}"
      if [ -r ${LOGFILE} ]; then
        printf "%s\n" "${color_hide} ${LOGFILE} ${color_orig}"
        tail -n${2} ${LOGFILE}
        printf "%s\n\n" "${color_show}^^^ '${JOBNAME}' (JobID: ${JOBID}) ^^^${color_orig}"
      else
        printf "%s\n\n" "${LOGFILE} is missing or no read permission."
      fi
    else
      printf "\n%s\n\n" "Cannot obtain the log file location for '${JOBNAME}' (JobID: ${JOBID})"
    fi
    sleep 0.1
  }
  local DISPLAY_COUNT=0
  if [ -n "${SINGLE_JOBID}" ]; then
    displaylog "${SINGLE_JOBID}" ${NUM_LINE}
    DISPLAY_COUNT=$((${DISPLAY_COUNT}+1))
  else
    while read -r line
    do
      local CURRENT_JOBID=${line%% *}
      displaylog "${CURRENT_JOBID}" ${NUM_LINE}
      DISPLAY_COUNT=$((${DISPLAY_COUNT}+1))
    done < <(squeue --me --long | grep 'RUNNING')
  fi

  if [ ${DISPLAY_COUNT} -eq 0 ]; then
    echo "  There is NO running job."
  fi
}
