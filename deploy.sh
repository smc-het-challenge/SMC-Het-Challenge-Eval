#!/bin/bash

ENTRY_ID=$1
TUMOR_ID=$2
TUMOR_LOWER=`echo $TUMOR_ID | tr "[[:upper:]]" "[[:lower:]]"`
DISK_SIZE=300
TIMEOUT=126000 #35 hours in seconds
MACHINE_TYPE=n1-standard-4
IMAGE=smc-het-eval-image

PROJECT=galaxyprojectsmc

gcloud compute disks create smc-het-eval-disk-$ENTRY_ID-$TUMOR_LOWER \
--source-snapshot $IMAGE --size $DISK_SIZE --project $PROJECT

gcloud compute instances create smc-het-eval-$ENTRY_ID-$TUMOR_LOWER \
--disk name=smc-het-eval-disk-$ENTRY_ID-$TUMOR_LOWER,auto-delete=yes,boot=yes \
--scopes storage-rw --machine-type $MACHINE_TYPE --project $PROJECT

sleep 40

gcloud compute --project $PROJECT ssh smc-het-eval-$ENTRY_ID-$TUMOR_LOWER "nohup sudo sudo -i -u ubuntu bash /home/ubuntu/SMC-Het-Challenge-Eval/eval_entry_tumor.sh $ENTRY_ID $TUMOR_ID $TIMEOUT > /tmp/eval.out 2> /tmp/eval.err &" 