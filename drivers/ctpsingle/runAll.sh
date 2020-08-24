#!/bin/bash

LIST=$1

for LINE in $(cat $LIST)
do
    TUMOR=`basename $LINE`
    mkdir $TUMOR
    pushd $TUMOR
    ../slurm_ctpsingle.sh $LINE /home/exacloud/lustre1/SpellmanLab/chiotti/smchet_dream/submission_repos/ctpsingle
    popd
done
