#!/bin/bash

BASE="$(cd `dirname $0`; pwd)"
ENTRY=$1
TUMOR=$2

cd $BASE

#. venv/bin/activate

TUMOR_DIR=gs://smc-het-evaluation/tumours/$TUMOR.tar.gz

if [ ! -e tumors ]; then
  mkdir tumors
fi
if [ ! -e entries ]; then
    mkdir entries
fi

gsutil cp -n -r $TUMOR_DIR ./tumors/

pushd tumors/
for a in *.gz; do 
  tar xvf $a; 
done
popd

gsutil cp -n -r gs://smc-het-evaluation/entries/$ENTRY ./entries/
venv/bin/python het-evaluate.py docker-rename ./entries/$ENTRY/
venv/bin/python het-evaluate.py unpack ./entries/$ENTRY/repack/

for a in tumors/$TUMOR/$TUMOR.mutect.vcf; do
  b=`echo $a | sed -e 's/.mutect.vcf$//'`
  name=`basename $a | sed -e 's/.mutect.vcf$//'`
  if [ ! -e output/$ENTRY/$name ]; then
    mkdir -p output/$ENTRY/$name
  fi
  bash ./run_eval_entry_tumor.sh entries/$ENTRY/repack/ $b output/$ENTRY/$name
  gsutil cp -n -r output/* gs://smc-het-evaluation/results/
done


if [ "$3" == "shutdown" ]; then
  sudo poweroff
fi
