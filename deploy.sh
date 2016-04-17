#!/bin/bash

EVAL_ID=$1

gcloud compute disks create smc-het-eval-disk-$EVAL_ID \
--source-snapshot smc-het-testing --size 50

gcloud compute instances create smc-het-eval-$EVAL_ID \
--disk name=smc-het-eval-disk-$EVAL_ID,auto-delete=yes,boot=yes \
--scopes storage-rw --machine-type n1-standard-4
