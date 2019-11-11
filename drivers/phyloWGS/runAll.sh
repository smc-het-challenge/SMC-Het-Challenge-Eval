#!/bin/bash

for a in /home/exacloud/lustre1/SpellmanLab/chiotti/smchet_dream/tumors/*; do
    b=`basename $a`
    mkdir $b
    pushd $b
    ../slurm_phyloWGS.sh $a /home/exacloud/lustre1/SpellmanLab/chiotti/smchet_dream/submission_repos/phyloWGS
    popd
done
