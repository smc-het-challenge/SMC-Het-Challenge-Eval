#!/bin/bash

BASE=$(cd $(dirname $0); pwd)
ENTRY=`realpath $1`
ENTRY_NAME=`basename $1 | sed s'/.tar.gz//'`
TUMOR_DIR=$(cd $(dirname $2); pwd)
TUMOR_NAME=$(basename $2)

TUMOR=$TUMOR_DIR/$TUMOR_NAME
echo Tumor $TUMOR
TRUTH=$TUMOR.truth
WORKDIR=`mktemp -d ./smc_eval_XXXXXX`
pushd $WORKDIR
tar xvzf $ENTRY

if [ -e cellularity.predfile ]; then
   python $BASE/SMC-Het-Challenge/smc_het_eval/SMCScoring.py --predfiles cellularity.predfile --truthfiles $TRUTH.1A.txt -c 1A -o $BASE/scores/$ENTRY_NAME.1A
fi
if [ -e population.predfile ]; then 
   python $BASE/SMC-Het-Challenge/smc_het_eval/SMCScoring.py --predfiles population.predfile --truthfiles $TRUTH.1B.txt -c 1B -o $BASE/scores/$ENTRY_NAME.1B
fi
if [ -e proportion.predfile ]; then
   python $BASE/SMC-Het-Challenge/smc_het_eval/SMCScoring.py --predfiles proportion.predfile --truthfiles $TRUTH.1C.txt -c 1C -o $BASE/scores/$ENTRY_NAME.1C --vcf $TRUTH.scoring_vcf.vcf 
fi
if [ -e cluster_assignment.predfile ]; then
   python $BASE/SMC-Het-Challenge/smc_het_eval/SMCScoring.py --predfiles cluster_assignment.predfile --truthfiles $TRUTH.2A.txt -c 2A --vcf $TRUTH.scoring_vcf.vcf -o $BASE/scores/$ENTRY_NAME.2A
fi
if [ -e cocluster_assignment.predfile ]; then
   python $BASE/SMC-Het-Challenge/smc_het_eval/SMCScoring.py --predfiles cocluster_assignment.predfile --truthfiles $TRUTH.2B.gz -c 2B --vcf $TRUTH.scoring_vcf.vcf -o $BASE/scores/$ENTRY_NAME.2B
fi
if [ -e cluster_assignment.phylogeny.predfile ]; then 
   python $BASE/SMC-Het-Challenge/smc_het_eval/SMCScoring.py --predfiles cluster_assignment.predfile cluster_assignment.phylogeny.predfile --truthfiles $TRUTH.2A.txt $TRUTH.3A.txt --vcf $TRUTH.scoring_vcf.vcf -o $BASE/scores/$ENTRY_NAME.3A -c 3A
fi
if [ -e cocluster_assignment.ancestor.predfile ]; then
   python $BASE/SMC-Het-Challenge/smc_het_eval/SMCScoring.py --predfiles cocluster_assignment.predfile cocluster_assignment.ancestor.predfile --truthfiles $TRUTH.2B.gz $TRUTH.3B.gz  --vcf $TRUTH.scoring_vcf.vcf -o $BASE/scores/$ENTRY_NAME.3B -c 3B
fi

popd
rm -rf $WORKDIR
