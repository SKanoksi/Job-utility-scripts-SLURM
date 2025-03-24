#
# Job utlity functions -- SLURM
#
# Copyright (c) 2024, Somrath Kanoksirirath.
# All rights reserved under BSD 3-clause license.
#
#
# *** Hardware utilization ***
# 1) gpu_usage  <jobid>
#    gpu_usage2 <jobid> <nodename> [-G <num-gpu-on-node>]
# 2) cpu_usage  <jobid> <nodename>
#    ps_stat    <jobid> <nodename>        <-- only if srun step is used
# 3) rss_usage  <jobid> <nodename>      <-- only if srun step is used
# 4) cpu_freq_usage <jobid>
#
# WARNING: Don’t query too often, since they interferes with your main workload and steal computing time !!!
#
#
# *** Other utility tools ***
# 1) tojob [jobid]
# 2) tailjob [jobid]
# 3) myq
# 4) get_timelimit
# 5) get_timeleft
#
# ---------------------------

function gpu_usage(){
  if [ -z "${1}" ] || ! [[ ${1} =~ ^[1-9][0-9_]*$ ]]; then
    echo "Usage: gpu_usage2 <your-jobid>"
    return 1
  fi

  function srun_nvidia_smi_query(){
    echo ""
    echo "######################################"
    echo "        ${3} GPUs on ${2}"
    echo "######################################"
    srun --input none --jobid=${1} -w ${2} -N1 -n1 -c1 -G${3} -u --overlap nvidia-smi
    echo ""
    sleep 0.01
  }

  local GPU_SET_COUNT="0"
  while read -r line
  do
    GPU_SET_COUNT=$((${GPU_SET_COUNT}+1))

    local JOB_NODELIST=${line#*Nodes=}
    JOB_NODELIST=${JOB_NODELIST%% CPU_IDs=*}
    local JOB_NODE_GPU_COUNT=${line%%(IDX*}
    JOB_NODE_GPU_COUNT=${JOB_NODE_GPU_COUNT##*GRES=gpu:*:}

    local NODE_PREFIX=${JOB_NODELIST%%[*}
    if [ "${NODE_PREFIX}" = "${JOB_NODELIST}" ]; then
      srun_nvidia_smi_query "${1}" "${NODE_PREFIX}" "${JOB_NODE_GPU_COUNT}"
      continue
    fi

    JOB_NODELIST=${JOB_NODELIST#*[}
    JOB_NODELIST=${JOB_NODELIST%%]*}
    IFS=',' read -ra JOB_NODE_ITEM_LIST <<< "${JOB_NODELIST}"
    local NODE_NUM=""
    for NODE_ITEM in "${JOB_NODE_ITEM_LIST[@]}"
    do
      if [[ "${NODE_ITEM}" == *"-"* ]]; then
        for ii in $(seq -f "%03g" ${NODE_ITEM%%-*} 1 ${NODE_ITEM#*-})
        do
          srun_nvidia_smi_query "${1}" "${NODE_PREFIX}${ii}" "${JOB_NODE_GPU_COUNT}"
        done
      else
        NODE_NUM=$(printf "%03g" "${NODE_ITEM}")
        srun_nvidia_smi_query "${1}" "${NODE_PREFIX}${NODE_NUM}" "${JOB_NODE_GPU_COUNT}"
      fi
    done

  done < <(scontrol -d --quiet show job ${1} | grep -A 30 "${UID}" | grep 'CPU_IDs')

  if [ ${GPU_SET_COUNT} -eq 0 ]; then
    echo "ERROR: Invalid JobID was specified. Is your job running?"
  fi
}


function gpu_usage2(){
  if [ -z "${2}" ]; then
    echo "Usage: gpu_usage <your-jobid> <one-of-the-job-nodename> [-G <num-gpu-on-node>]"
  else
    srun --jobid=${1} -w ${2} -N1 -c1 --ntasks-per-node=1 ${@:3} -u --overlap nvidia-smi
    RTC=$?
    if [ ${RTC} -ne 0 ]; then
      printf "\nUsage: gpu_usage <your-jobid> <one-of-the-job-nodename> [-G <num-gpu-on-node>]\n\nn"
    fi
  fi
}
# Note: if use #SBATCH --gpus= and >1 nodes are allocated
#       --> need to specify -G <Num-GPU-on-node> after <job-node>


function cpu_usage(){
  if [ -z "${2}" ]; then
    echo "Usage: cpu_usage <your-jobid> <one-of-the-job-nodename>"
  else
    srun --jobid=${1} -w ${2} -N1 -c1 --ntasks-per-node=1 -u --overlap top -b -n1 -Eg -u ${USER}
    RTC=$?
    if [ ${RTC} -ne 0 ]; then
      printf "\nUsage: cpu_usage <your-jobid> <one-of-the-job-nodename>\n\n"
    fi
  fi
}


function ps_stat(){
  if [ -z "${2}" ]; then
    echo "Usage: ps_stat <your-jobid> <one-of-the-job-nodename>"
    return 1
  fi
  local JOB_NODE_PIDS=$(sstat -j ${1} -i -n -o pids%2000 | grep "${2}" | awk '{list = $3} END {print list}')
  if [ -n "${JOB_NODE_PIDS}" ]; then
    srun --jobid=${1} -w ${2} -N1 -c1 --ntasks-per-node=1 -u --overlap ps -p ${JOB_NODE_PIDS} -o user,pid,thcount,numa,pcpu,rss,vsz,start_time,etime,state,comm rf | numfmt --header --from-unit=1024 --to=iec-i --field 6,7 --padding 6
  else
    printf "\nUsage: ps_stat <your-jobid> <one-of-the-job-nodename>\n\n"
    echo "ERROR:: Cannot get the job's PIDs -- Please check that 1) The JobID and its nodename are correct 2) srun is used in the job script 3) The job is running"
  fi
}


function rss_usage(){
  if [ -z "${2}" ]; then
    echo "Usage: rss_usage <your-jobid> <one-of-the-job-nodename>"
    return 1
  fi
  local JOB_NODE_PIDS=$(sstat -j ${1} -i -n -o pids%2000 | grep "${2}" | awk '{list = $3} END {print list}')
  if [ -n "${JOB_NODE_PIDS}" ]; then
    echo "Total RSS of all user's processes inside JobID ${1} on ${2}"
    srun --jobid=${1} -w ${2} -N1 -c1 --ntasks-per-node=1 -u --overlap ps -p ${JOB_NODE_PIDS} -o rss= | awk '{sum+=$1} END {printf "--> %d KiB = %.2f MiB = %.2f GiB \n", sum, sum/1024, sum/1024/1024}'
  else
    printf "\nUsage: rss_usage <your-jobid> <one-of-the-job-nodename>\n\n"
    echo "ERROR:: Cannot get the job's PIDs -- Please check that 1) The JobID and its nodename are correct 2) srun is used in the job script 3) The job is running"
  fi
}


function cpu_freq_usage(){
  if [ -z "${1}" ] || ! [[ ${1} =~ ^[1-9][0-9_]*$ ]]; then
    echo "Usage: cpu_freq_usage <your-jobid>"
    return 1
  fi

  function srun_cpu_power_query(){
    echo "######################################"
    echo " CPUID_[${3}] on ${2}"
    echo "######################################"
    if ! [[ ${4} =~ ^[1-9][0-9_]*$ ]]; then
      srun --input none --jobid=${1} -w ${2} -N1 -c1 --ntasks-per-node=1 -u --overlap cpupower --cpu ${3} frequency-info -f  | grep 'current CPU frequency' | awk '{printf "%3d:  %.3f MHz\n", NR, $4/1000 ;sum+=$4;count++} END  {if (count>0) printf "\nAveraged CPU frequency = %.3f GHz", sum/count/1000000}'
    else
      srun --input none --jobid=${1} -w ${2} -N1 -n1 -c1 -G${4} -u --overlap cpupower --cpu ${3} frequency-info -f  | grep 'current CPU frequency' | awk '{printf "%3d:  %.3f MHz\n", NR, $4/1000 ;sum+=$4;count++} END  {if (count>0) printf "\nAveraged CPU frequency = %.3f GHz", sum/count/1000000}'
    fi
    printf " on %s\n\n" ${2}
    sleep 0.01
  }

  local CPUID_SET_COUNT="0"
  while read -r line
  do
    CPUID_SET_COUNT=$((${CPUID_SET_COUNT}+1))

    local JOB_NODELIST=${line#*Nodes=}
    JOB_NODELIST=${JOB_NODELIST%% CPU_IDs=*}
    local JOB_NODE_CPU_IDS=${line#*CPU_IDs=}
    JOB_NODE_CPU_IDS=${JOB_NODE_CPU_IDS%% Mem=*}
    local JOB_NODE_GPU_COUNT=${line%%(IDX*}
    JOB_NODE_GPU_COUNT=${JOB_NODE_GPU_COUNT##*GRES=gpu:*:}

    local NODE_PREFIX=${JOB_NODELIST%%[*}
    if [ "${NODE_PREFIX}" = "${JOB_NODELIST}" ]; then
      srun_cpu_power_query "${1}" "${NODE_PREFIX}" "${JOB_NODE_CPU_IDS}" "${JOB_NODE_GPU_COUNT}"
      continue
    fi

    JOB_NODELIST=${JOB_NODELIST#*[}
    JOB_NODELIST=${JOB_NODELIST%%]*}
    IFS=',' read -ra JOB_NODE_ITEM_LIST <<< "${JOB_NODELIST}"
    local NODE_NUM=""
    for NODE_ITEM in "${JOB_NODE_ITEM_LIST[@]}"
    do
      if [[ "${NODE_ITEM}" == *"-"* ]]; then
        for ii in $(seq -f "%03g" ${NODE_ITEM%%-*} 1 ${NODE_ITEM#*-})
        do
          srun_cpu_power_query "${1}" "${NODE_PREFIX}${ii}" "${JOB_NODE_CPU_IDS}" "${JOB_NODE_GPU_COUNT}"
        done
      else
        NODE_NUM=$(printf "%03g" "${NODE_ITEM}")
        srun_cpu_power_query "${1}" "${NODE_PREFIX}${NODE_NUM}" "${JOB_NODE_CPU_IDS}" "${JOB_NODE_GPU_COUNT}"
      fi
    done

  done < <(scontrol -d --quiet show job ${1} | grep -A 30 "${UID}" | grep 'CPU_IDs')

  if [ ${CPUID_SET_COUNT} -eq 0 ]; then
    echo "ERROR: Invalid JobID was specified. Is your job running?"
  fi
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
      printf " CHOICE  JOBID\n"
      local INDEX=0
      local INPUT_INDEX=0
      while read -r line
      do
        INDEX=$((${INDEX}+1))
        printf " %-5s   %-s\n" "[${INDEX}]" "${line}"
      done < <(squeue --me --noheader --format=%i)
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


function get_timeleft(){

  local PRGNAME=${0##*/}
  local TIMEUNIT=SEC
  local ROUNDUP=
  local JOBID=

  this_usage () {
    printf "Usage: ${PRGNAME} [OPTIONS]...\n"
    printf "Parse remaining time availale for the job\n"
    printf "\n"
    printf "OPTIONS:\n"
    printf "  -j <job-id>      specify single job id. Default: SLURM_JOB_ID\n"
    printf "  -H, --hour       job timeleft in hours\n"
    printf "  -M, --minute     job timeleft in minutes\n"
    printf "  -S, --second     job timeleft in seconds (default)\n"
    printf "  --round-up       return ceil, otherwise floor\n"
    printf "  -h, --help       print this usage\n"
    printf "\n"
  }

  while [ $# -gt 0 ]; do
    case "$1" in
      -j)
        if [ -n "${2}" ] && [[ ${2} =~ ^[1-9][0-9_]*$ ]] ; then
          JOBID=$2
        fi
        shift
        ;;
      -H | --hour)
        TIMEUNIT=HOUR
        ;;
      -M | --minute)
        TIMEUNIT=MIN
        ;;
      -S | --second)
        TIMEUNIT=SEC
        ;;
      --round-up)
        ROUNDUP=TRUE
        ;;
      -h | --help)
        this_usage
        return 0
        ;;
      *)
        # Silently ignore unknown arguments
        ;;
    esac
    shift
  done

  if [ -z "${JOBID}" ]; then
    if [ -z "${SLURM_JOBID}" ]; then
      echo "${PRGNAME}: error: SLURM_JOBID is not specified."
      return 1
    else
      JOBID=${SLURM_JOBID}
    fi
  fi

  local timeleft=$(squeue -j "${JOBID}" -O timeleft --noheader)
  timeleft=${timeleft%% *}

  if [ -z "${timeleft}" ]; then
    echo "${PRGNAME}: error: Cannot get timeleft from squeue. Is the job running?"
    return 1
  fi
  if [ "${timeleft}" = "NOT_SET" ]; then
    echo "${PRGNAME}: error: TimeLimit and TimeLeft have not yet been established."
    return 1
  fi
  if [ "${timeleft}" = "UNLIMITED" ]; then
    echo "${PRGNAME}: error: TimeLimit and TimeLeft is UNLIMITED."
    return 1
  fi
  if [ "${timeleft}" = "INVALID" ]; then
    echo "${PRGNAME}: error: TimeLeft is INVALID."
    return 1
  fi

  IFS="-:" read -r DD HH MM SS <<< "${timeleft}"
  if [ -z "${SS}" ]; then
    DD=0
    IFS="-:" read -r HH MM SS <<< "${timeleft}"
  fi
  if [ -z "${SS}" ]; then
    DD=0
    HH=0
    IFS="-:" read -r MM SS <<< "${timeleft}"
  fi

  if [ "${ROUNDUP}" = "TRUE" ]; then
    case "$TIMEUNIT" in
      HOUR)
        if [[ ${MM} -ne "0" || ${SS} -ne "0" ]]; then
          echo $((24*${DD}+${HH}+1))
        else
          echo $((24*${DD}+${HH}))
        fi
        ;;
      MIN)
        if [ ${SS} -ne "0" ]; then
          echo $((1440*${DD}+60*${HH}+${MM}+1))
        else
          echo $((1440*${DD}+60*${HH}+${MM}))
        fi
        ;;
      *)
        echo $((86400*${DD}+3600*${HH}+60*${MM}+${SS}))
        ;;
    esac
  else
    case "$TIMEUNIT" in
      HOUR)
        echo $((24*${DD}+${HH}))
        ;;
      MIN)
        echo $((1440*${DD}+60*${HH}+${MM}))
        ;;
      *)
        echo $((86400*${DD}+3600*${HH}+60*${MM}+${SS}))
        ;;
    esac
  fi

}


function get_timelimit(){
  local PRGNAME=${0##*/}
  local TIMEUNIT=SEC
  local ROUNDUP=
  local JOBID=

  this_usage () {
    printf "Usage: ${PRGNAME} [OPTIONS]...\n"
    printf "Parse timelimit of the Slurm job\n"
    printf "\n"
    printf "OPTIONS:\n"
    printf "  -j <job-id>      specify single job id. Default: SLURM_JOB_ID\n"
    printf "  -H, --hour       job timelimit in hours\n"
    printf "  -M, --minute     job timelimit in minutes\n"
    printf "  -S, --second     job timelimit in seconds (default)\n"
    printf "  --round-up       return ceil, otherwise floor\n"
    printf "  -h, --help       print this usage\n"
    printf "\n"
  }

  while [ $# -gt 0 ]; do
    case "$1" in
      -j)
        if [ -n "${2}" ] && [[ ${2} =~ ^[1-9][0-9_]*$ ]] ; then
          JOBID=$2
        fi
        shift
        ;;
      -H | --hour)
        TIMEUNIT=HOUR
        ;;
      -M | --minute)
        TIMEUNIT=MIN
        ;;
      -S | --second)
        TIMEUNIT=SEC
        ;;
      --round-up)
        ROUNDUP=TRUE
        ;;
      -h | --help)
        this_usage
        return 0
        ;;
      *)
        # Silently ignore unknown arguments
        ;;
    esac
    shift
  done

  if [ -z "${JOBID}" ]; then
    if [ -z "${SLURM_JOBID}" ]; then
      echo "${PRGNAME}: error: SLURM_JOBID is not specified."
      return 1
    else
      JOBID=${SLURM_JOBID}
    fi
  fi

  local timelimit=$(scontrol --quiet show job "${JOBID}" | grep 'TimeLimit=')
  timelimit=${timelimit#*TimeLimit=}
  timelimit=${timelimit%% *}

  if [ -z "${timelimit}" ]; then
    timelimit=$(sacct -j "${JOBID}" --format=timelimit -X --noheader | tr -d ' ')
  fi

  if [ -z "${timelimit}" ]; then
    echo "${PRGNAME}: error: Cannot get timelimit from either scontrol or sacct."
    return 1
  fi

  if [[ ${timelimit} != *-* ]]; then
    timelimit="0-${timelimit}"
  fi

  IFS="-:" read -r DD HH MM SS <<< "${timelimit}"

  if [ "${ROUNDUP}" = "TRUE" ]; then
    case "$TIMEUNIT" in
      HOUR)
        if [[ ${MM} -ne "0" || ${SS} -ne "0" ]]; then
          echo $((24*${DD}+${HH}+1))
        else
          echo $((24*${DD}+${HH}))
        fi
        ;;
      MIN)
        if [ ${SS} -ne "0" ]; then
          echo $((1440*${DD}+60*${HH}+${MM}+1))
        else
          echo $((1440*${DD}+60*${HH}+${MM}))
        fi
        ;;
      *)
        echo $((86400*${DD}+3600*${HH}+60*${MM}+${SS}))
        ;;
    esac
  else
    case "$TIMEUNIT" in
      HOUR)
        echo $((24*${DD}+${HH}))
        ;;
      MIN)
        echo $((1440*${DD}+60*${HH}+${MM}))
        ;;
      *)
        echo $((86400*${DD}+3600*${HH}+60*${MM}+${SS}))
        ;;
    esac
  fi

}

