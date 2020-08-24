#!/bin/bash
# ccube.sh
#SBATCH --partition=exacloud
#SBATCH --account=spellmanlab
#SBATCH --time=24:00:00
#SBATCH --output=ccube-%j.out
#SBATCH --error=ccube-%j.err
#SBATCH --job-name=smchet-ccube
#SBATCH --gres disk:1024
#SBATCH --mincpus=2
#SBATCH --cpus-per-task=6
#SBATCH --mem=8G

function usage()
{
        echo "ccube.sh"    " [a.k.a. *this* script] "
        echo "Author: Kami E. Chiotti "
        echo "Date: 01.22.20"
        echo
        echo "A wrapper for the SMC-Het Dream Challenge submission, 'keyuan/docker-ccube'. It "
        echo "builds and launches the command to execute the ccube CWL CommandLineTool within a docker container, "
        echo "then collects and returns the output files as a tarball. "
        echo
        echo "NOTE #1: The 'ccube_template.json' template file must be in the same directory as *this* "
        echo "script. "
        echo "NOTE #2: The output will be written to a subdirectory called 'outputs' in the same directory"
        echo "         as *this* script. "
        echo
        echo "Usage: $0 [ -t TUMOR -c CWL -d DRIVERS -a ALPHA]"
        echo
        echo " [-t TUMOR]    - Full path to the *directory* containing the 'tumors' subdirectory; where 'tumors' "
        echo "                 holds a subdirectory for each tumor ID;  each within which resides VCF, CNA, and purity "
        echo "                 data specific to that tumor [e.g., /<full>/<path>/<to>/tumors/T0_noXY]."
        echo " [-c CWL]      - Full path to the CWL tool [e.g., /<full>/<path>/<to>/ccube.cwl"
        echo " [-d DRIVERS]  - Full path to *directory* containing shell, json, and submission scripts  [e.g., "
        echo "                 /<full>/<path>/<to>/drivers/ccube]. These are the scripts required to run the "
        echo "                 containerized ccube algorithm. "
        echo " [-a ALPHA     - Full path to the top directory of the ccube file tree, which contains the scripts "
        echo "                 that run the ccube algorithm itself. "
        exit
}

TUMOR=""
while getopts ":t:c:d:a:h" Option
        do
        case $Option in
                t ) TUMOR="$OPTARG" ;;
                c ) CWL="$OPTARG" ;;
                d ) DRIVERS="$OPTARG" ;;
                a ) ALPHA="$OPTARG" ;;
                h ) usage ;;
                * ) echo "unrecognized argument. use '-h' for usage information."; exit -1 ;;
        esac
done
shift $(($OPTIND - 1))

if [[ "$TUMOR" == "" || "$CWL" == "" || "$DRIVERS" == "" || "$ALPHA" == "" ]]
then
        usage
fi

source /home/groups/EllrottLab/activate_conda

if [ ! -e $TUMOR ];
then
    echo "Input data directory for $TUMOR does not exist"; exit -1 ;
fi
if [ ! -e $CWL ];
then
    echo "Input CWL tool $CWL does not exist"; exit -1 ;
fi
if [ ! -e $DRIVERS ];
then
    echo "DRIVERS directory does not exist"; exit -1 ;
fi
if [ ! -e $ALPHA ];
then
    echo "ALPHA directory does not exist"; exit -1 ;
fi

cd $DRIVERS
TMPJSON=$DRIVERS/ccube_template.json
VCF=$TUMOR/*mutect.vcf
CNA=$TUMOR/*battenberg.txt
CELLULARITY=$TUMOR/*cellularity_ploidy.txt
OUTDIR=$DRIVERS/`basename $TUMOR`/ccube_outputs

if [ ! -e $OUTDIR ];
then
    mkdir -p $OUTDIR ;
fi

WORKDIR=`mktemp -d -p /mnt/scratch/ ccube.XXX`
chmod -R 775 $WORKDIR
chmod -R g+s $WORKDIR
JSON=$WORKDIR/ccube_template.json

sed -e "s|vcf_in|$WORKDIR\/`basename $VCF`|g" -e "s|cna_in|$WORKDIR\/`basename $CNA`|g" -e "s|pur_in|$WORKDIR\/`basename $CELLULARITY`|g" $TMPJSON > $JSON
cp $VCF $CNA $CELLULARITY $ALPHA/*cwl $ALPHA/run_analysis_ccube_bb.R $ALPHA/create_ccfclust_inputs.py $WORKDIR

cd $WORKDIR
time (cwltool --tmpdir-prefix $WORKDIR/tmpdir/ --tmp-outdir-prefix $WORKDIR/tmpoutdir/ `basename $CWL` `basename $JSON` 1> $OUTDIR/log.txt) 2> $OUTDIR/runtime.txt

if [ ! -z $WORKDIR/2B.txt ]; then gzip $WORKDIR/2B.txt; fi

if [ ! -z $WORKDIR/1A.txt ]; then mv $WORKDIR/1A.txt $WORKDIR/cellularity.predfile; fi
if [ ! -z $WORKDIR/1B.txt ]; then mv $WORKDIR/1B.txt $WORKDIR/population.predfile; fi
if [ ! -z $WORKDIR/1C.txt ]; then mv $WORKDIR/1C.txt $WORKDIR/proportion.predfile; fi
if [ ! -z $WORKDIR/2A.txt ]; then mv $WORKDIR/2A.txt $WORKDIR/cluster_assignment.predfile; fi
if [ ! -z $WORKDIR/2B.txt.gz ]; then mv $WORKDIR/2B.txt.gz $WORKDIR/cocluster_assignment.predfile; fi
tar -czf ccube.tar.gz *predfile
rsync -a ccube.tar.gz $OUTDIR

cd $ALPHA
rm -rf $WORKDIR
