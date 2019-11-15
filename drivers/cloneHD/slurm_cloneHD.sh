#$!/user/bin/bash

ABS_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
sbatch $ABS_PATH/run_cloneHD.sh -t ${1} -c ${2} -d $ABS_PATH

