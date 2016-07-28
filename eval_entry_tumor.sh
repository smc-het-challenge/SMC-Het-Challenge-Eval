#!/bin/bash

BASE="$(cd `dirname $0`; pwd)"
ENTRY=$1
TUMOR=$2

cd $BASE

#. venv/bin/activate

TUMOR_DIR=gs://smc-het-entries/test_tumors/$TUMOR

if [ ! -e tumors ]; then
  mkdir tumors
fi

gsutil cp -n -r $TUMOR_DIR ./tumors/

pushd tumors/
for a in *.gz; do 
  tar xvf $a; 
done
popd

gsutil cp -n -r gs://smc-het-entries/$ENTRY ./
venv/bin/python het-evaluate.py docker-rename $ENTRY/
venv/bin/python het-evaluate.py unpack $ENTRY/repack/

for a in tumors/*/*.mutect.vcf; do
  b=`echo $a | sed -e 's/.mutect.vcf$//'`
  name=`basename $a | sed -e 's/.mutect.vcf$//'`
  if [ ! -e output/$ENTRY/$name ]; then
    mkdir -p output/$ENTRY/$name
  fi
  bash ./run_eval_entry_tumor.sh $ENTRY/repack/ $b output/$ENTRY/$name
  gsutil cp -n -r output/* gs://smc-het-entries/results/
done


if [ -e "$2" == "shutdown" ]; then
  sudo poweroff
fi0