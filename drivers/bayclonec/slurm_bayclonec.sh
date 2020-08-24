#$!/user/bin/bash

ABS_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

sbatch $ABS_PATH/bayclonec.sh -t ${1} -c ${2}/bayclonec.cwl -d $ABS_PATH -a ${2}

