#$!/user/bin/bash

ABS_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

sbatch $ABS_PATH/phyloWGS.sh -t ${1} -c ${2}/phylowgs/phylowgs.cwl -d $ABS_PATH -a ${2}

