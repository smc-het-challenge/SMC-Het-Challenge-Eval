#!/bin/bash

$BASE="$(cd `dirname $0`; pwd)"

ENTRY=$1

. venv/bin/activate
cd $BASE
mkdir tumors

pushd tumors/
for a in 1 2 3 7; do 
  curl -O https://storage.googleapis.com/galaxyproject_images/Tumour$a.tar.gz ; 
done
for a in *.gz; do 
  tar xvf $a; 
done
popd

for a in 1 2 3 7; do 
  ./evaluate.py --agro test_data load-input Tumour$a tumors/Tumour$a/Tumour$a.mutect.vcf tumors/Tumour$a/Tumour$a.battenberg.txt ; 
done

gsutil cp -r gs://smc-het-entries/$ENTRY ./
./evaluate.py docker-rename $ENTRY

for a in $ENTRY/repack/*.tar; do 
  docker load -i $a; 
done

tar cvzf smc_het_evalcopy.tar.gz smc_het_evalcopy

for a in 1 2 3 7; do 
  ./evaluate.py --agro test_data run Tumour$a $ENTRY $ENTRY/repack/
done
./evaluate.py --agro test_data extract

gsutil cp -r output/* gs://smc-het-entries/results/
