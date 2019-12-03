#!/bin/bash
# pyclone.sh
#SBATCH --partition=exacloud
#SBATCH --account=spellmanlab
#SBATCH --time=08:00:00
#SBATCH --output=pyclone-%j.out
#SBATCH --error=pyclone-%j.err
#SBATCH --job-name=smchet-pyclone
#SBATCH --gres disk:1024
#SBATCH --mincpus=2
#SBATCH --cpus-per-task=6
#SBATCH --mem=30G

function usage()
{
        echo "pyclone.sh"    " [a.k.a. *this* script] "
        echo "Author: Kami E. Chiotti "
        echo "Date: 11.25.19"
        echo
        echo "A wrapper for the SMC-Het Dream Challenge submission, 'keyuan/docker-pyclone'. It "
        echo "builds and launches the command to execute the PyClone CWL CommandLineTool within a docker container, "
        echo "then collects and returns the output files as a tarball. "
        echo
        echo "NOTE #1: The 'pyclone_template.json' template file must be in the same directory as *this* "
        echo "script. "
        echo "NOTE #2: The output will be written to a subdirectory called 'outputs' in the same directory"
        echo "         as *this* script. "
        echo
        echo "Usage: $0 [ -t TUMOR -c CWL -d DRIVERS -a ALPHA]"
        echo
        echo " [-t TUMOR]    - Full path to the *directory* containing the 'tumors' subdirectory; where 'tumors' "
        echo "                 holds a subdirectory for each tumor ID;  each within which resides VCF and CNA "
        echo "                 data specific to that tumor [e.g., /<full>/<path>/<to>/tumors/T0_noXY]."
        echo " [-c CWL]      - Full path to the CWL tool [e.g., /<full>/<path>/<to>/pyclone.cwl"
        echo " [-d DRIVERS]  - Full path to *directory* containing shell, json, and submission scripts  [e.g., "
        echo "                 /<full>/<path>/<to>/drivers/pyclone]. These are the scripts required to run the "
        echo "                 containerized PyClone algorithm. "
        echo " [-a ALPHA     - Full path to the top directory of the pyclone file tree, which contains the scripts "
        echo "                 that run the PyClone algorithm itself. "
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
#ALPHA="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

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
TMPJSON=$DRIVERS/pyclone_template.json
VCF=$TUMOR/*mutect.vcf
CNA=$TUMOR/*battenberg.txt
CELLULARITY=$TUMOR/*cellularity_ploidy.txt
OUTDIR=$DRIVERS/`basename $TUMOR`/pyclone_outputs

if [ ! -e $OUTDIR ];
then
    mkdir -p $OUTDIR ;
fi

WORKDIR=`mktemp -d -p /mnt/scratch/ pyclone.XXX`
chmod -R 775 $WORKDIR
chmod -R g+s $WORKDIR
JSON=$WORKDIR/pyclone_template.json

sed -e "s|vcf_in|$WORKDIR\/`basename $VCF`|g" -e "s|cna_in|$WORKDIR\/`basename $CNA`|g" -e "s|purity_in|$WORKDIR\/`basename $CELLULARITY`|g" $TMPJSON > $JSON
cp $VCF $CNA $ALPHA/*cwl $WORKDIR

cd $WORKDIR
( time cwltool `basename $CWL` `basename $JSON` ) 2> $OUTDIR/runtime.txt

if [ ! -z $WORKDIR/1B.txt ]; then mv $WORKDIR/1B.txt $WORKDIR/population.predfile; fi
if [ ! -z $WORKDIR/1C.txt ]; then mv $WORKDIR/1C.txt $WORKDIR/proportion.predfile; fi
if [ ! -z $WORKDIR/2A.txt ]; then mv $WORKDIR/2A.txt $WORKDIR/cluster_assignment.predfile; fi
if [ ! -z $WORKDIR/2B.txt.gz ]; then mv $WORKDIR/2B.txt $WORKDIR/cocluster_assignment.predfile; fi
if [ ! -z $WORKDIR/clonal_results_summary.pdf ]; then mv $WORKDIR/clonal_results_summary.pdf $WORKDIR/clonal_results_summary.predfile

tar -czf pyClone.tar.gz *predfile
rsync -a pyClone.tar.gz $OUTDIR

cd $ALPHA
rm -rf $WORKDIR

