#!/bin/bash

ENTRY=$1
TUMOR=$2
TIMEOUT=$3


sleep $TIMEOUT

date > timeout.txt

gsutil cp timeout.txt gs://smc-het-evaluation/outputs/$ENTRY/$TUMOR/

sudo shutdown