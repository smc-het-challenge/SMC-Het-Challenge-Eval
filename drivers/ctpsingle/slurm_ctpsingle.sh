#$!/user/bin/bash

ABS_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

sbatch $ABS_PATH/ctpsingle.sh -t ${1} -c ${2}/ctpsingle.cwl -d $ABS_PATH -a ${2}

