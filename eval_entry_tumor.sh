#!/bin/bash

ENTRY_DIR=$1
TUMOR_BASE=$2
OUTDIR=$3
TUMOR_NAME=`basename $TUMOR_BASE`

mkdir -p $OUTDIR
python het-evaluate.py run $TUMOR_BASE $ENTRY_DIR $OUTDIR
