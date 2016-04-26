#!/bin/bash

ENTRY=$1

for a in Tumour1 Tumour2 Tumour3 Tumour7; do
	 PRED=../results/$a/$ENTRY.tar.gz
	 TRUTH=../tumors/$a/$a.truth
	 WORKDIR=`mktemp -d ./smc_eval_XXXXXX`
	 pushd $WORKDIR
	 tar xvzf $PRED

	 if [ -e cellularity.predfile ]; then
	     python ../SMC-Het-Challenge/smc_het_eval/SMCScoring.py --predfiles cellularity.predfile --truthfiles $TRUTH.1A.txt -c 1A -o ../scores/$ENTRY.$a.1A
	 fi
	 if [ -e population.predfile ]; then 
	     python ../SMC-Het-Challenge/smc_het_eval/SMCScoring.py --predfiles population.predfile --truthfiles $TRUTH.1B.txt -c 1B -o ../scores/$ENTRY.$a.1B
	 fi
	 if [ -e proportion.predfile ]; then
	     python ../SMC-Het-Challenge/smc_het_eval/SMCScoring.py --predfiles proportion.predfile --truthfiles $TRUTH.1C.txt -c 1C -o ../scores/$ENTRY.$a.1C --vcf $TRUTH.scoring_vcf.vcf 
	 fi
	 if [ -e cluster_assignment.predfile ]; then
	     python ../SMC-Het-Challenge/smc_het_eval/SMCScoring.py --predfiles cluster_assignment.predfile --truthfiles $TRUTH.2A.txt -c 2A --vcf $TRUTH.scoring_vcf.vcf -o ../scores/$ENTRY.$a.2A
	 fi
	 if [ -e cocluster_assignment.predfile ]; then
	     python ../SMC-Het-Challenge/smc_het_eval/SMCScoring.py --predfiles cocluster_assignment.predfile --truthfiles $TRUTH.2B.gz -c 2B --vcf $TRUTH.scoring_vcf.vcf -o ../scores/$ENTRY.$a.2B
	 fi
	 if [ -e cluster_assignment.phylogeny.predfile ]; then 
	     python ../SMC-Het-Challenge/smc_het_eval/SMCScoring.py --predfiles cluster_assignment.predfile cluster_assignment.phylogeny.predfile --truthfiles $TRUTH.2A.txt $TRUTH.3A.txt --vcf $TRUTH.scoring_vcf.vcf -o ../scores/$ENTRY.$a.3A -c 3A
	 fi
	 if [ -e cocluster_assignment.ancestor.predfile ]; then
	     python ../SMC-Het-Challenge/smc_het_eval/SMCScoring.py --predfiles cocluster_assignment.predfile cocluster_assignment.ancestor.predfile --truthfiles $TRUTH.2B.gz $TRUTH.3B.gz  --vcf $TRUTH.scoring_vcf.vcf -o ../scores/$ENTRY.$a.3B -c 3B
	 fi

	 popd
	 rm -rf $WORKDIR
done
