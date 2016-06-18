#!/bin/bash

BASE="$(cd `dirname $0`; pwd)"
ENTRY=$1

cd $BASE

#. venv/bin/activate

TUMORS=gs://smc-het-entries/test_tumors/*
#TUMORS=gs://evaluation_tumours/*

if [ ! -e tumors ]; then
  mkdir tumors
fi

gsutil cp -n -r $TUMORS ./tumors

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
  bash ./eval_entry_tumor.sh $ENTRY/repack/ $b output/$ENTRY/$name
done

gsutil cp -r output/* gs://smc-het-entries/results/

if [ -e "$2" == "shutdown" ]; then
  sudo poweroff
fi