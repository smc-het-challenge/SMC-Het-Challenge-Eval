#!/bin/bash

EVAL_ID=$1
DISK_SIZE=150

gcloud compute disks create smc-het-eval-disk-$EVAL_ID \
--source-snapshot smc-het-testing --size $DISK_SIZE

gcloud compute instances create smc-het-eval-$EVAL_ID \
--disk name=smc-het-eval-disk-$EVAL_ID,auto-delete=yes,boot=yes \
--scopes storage-rw --machine-type n1-standard-4


 gcloud compute ssh smc-het-eval-$EVAL_ID "nohup sudo sudo -u ubuntu bash /home/ubuntu/SMC-Het-Challenge-Eval/eval_entry.sh $EVAL_ID shutdown > test.out 2> test.err &" 