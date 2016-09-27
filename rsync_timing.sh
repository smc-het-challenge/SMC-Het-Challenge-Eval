#!/bin/bash


for a in `gsutil -m ls gs://smc-het-evaluation/outputs/*/*/* | egrep '.json|timeout.txt'`; do
  entry=$(basename $(dirname $(dirname $a)))
  tumor=$(basename $(dirname $a))
  mkdir -p outputs/$entry/$tumor
  gsutil cp $a outputs/$entry/$tumor/
done