#!/bin/bash
# phyloWGS.sh
#SBATCH --partition=exacloud
#SBATCH --qos long_jobs
#SBATCH --time=9-0
#SBATCH --output=phylowgs-%j.out
#SBATCH --error=phylowgs-%j.err
#SBATCH --job-name=smchet-phylowgs
#SBATCH --gres disk:1024
#SBATCH --mincpus=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=30G

function usage()
{
        echo "phyloWGS.sh"    " [a.k.a. *this* script] "
        echo "Author: Kami E. Chiotti "
        echo "Date: 10.28.19"
        echo
        echo "A wrapper for the SMC-Het Dream Challenge submission, 'morrislab/smchet-challenge'. It "
        echo "builds and launches the command to execute the PhyloWGS CWL Worflow within a docker container, "
        echo "then collects and returns the output files as a tarball. It is made up of five CWL tools: 1) "
        echo "parse_cnvs.cwl, 2) create_phylowgs_inputs.cwl, 3) multievolve.cwl, 4) write_results.cwl, and 5)"
        echo "write_report.cwl."
        echo
        echo "NOTE #1: The 'phyloWGS_template.json' template file must be in the same directory as *this* "
        echo "script. "
        echo "NOTE #2: The output will be written to a subdirectory called 'outputs' in the same directory"
        echo "         as *this* script. "
        echo
        echo "Usage: $0 [ -t TUMOR -c CWL -d DRIVERS -a ALPHA]"
        echo
        echo " [-t TUMOR]    - Full path to the *directory* containing the 'tumors' subdirectory; where 'tumors' "
        echo "                 holds a subdirectory for each tumor ID;  each within which resides VCF and CNA "
        echo "                 data specific to that tumor [e.g., /<full>/<path>/<to>/tumors/T0_noXY]."
        echo " [-c CWL]      - Full path to the CWL tool [e.g., /<full>/<path>/<to>/phyloWGS.cwl"
        echo " [-d DRIVERS]  - Full path to *directory* containing shell, json, and submission scripts  [e.g., "
        echo "                 /<full>/<path>/<to>/drivers/phyloWGS]"
        echo " [-a ALPHA     - Full path the top directory of the PhyloWGS tree. This directory will contain the "
        echo "                 'phylowgs' and 'smchet-challenge' subdirectories [e.g., /<full>/<path>/<to>/phyloWGS]"
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
TMPJSON=$DRIVERS/phyloWGS_template.json
VCF=$TUMOR/*mutect.vcf
CNA=$TUMOR/*battenberg.txt
CELLULARITY=`awk 'NR==2{print $1}' $TUMOR/*cellularity_ploidy.txt`
OUTDIR=$DRIVERS/`basename $TUMOR`/phyloWGS_outputs

if [ ! -e $OUTDIR ];
then
    mkdir -p $OUTDIR
fi

WORKDIR=`mktemp -d -p /mnt/scratch/ phyloWGS.XXX`
PHYLODIR=$WORKDIR/phylowgs
HETDIR=$WORKDIR/smchet-challenge
mkdir -p $PHYLODIR
mkdir -p $PHYLODIR/parser
mkdir -p $HETDIR
mkdir -p $HETDIR/create-smchet-report
chmod -R 775 $WORKDIR
chmod -R g+s $WORKDIR
JSON=$PHYLODIR/phyloWGS_template.json

sed -e "s|input_vcf|$PHYLODIR\/`basename $VCF`|g" -e "s|input_cna|$PHYLODIR\/`basename $CNA`|g" -e  "s|cancer_fxn|$CELLULARITY|g" $TMPJSON > $JSON
cp $VCF $CNA $ALPHA/phylowgs/*cwl $PHYLODIR
cp $ALPHA/phylowgs/parser/*cwl $PHYLODIR/parser
cp $ALPHA/smchet-challenge/create-smchet-report/*cwl $HETDIR/create-smchet-report

cd $PHYLODIR
cwltool `basename $CWL` `basename $JSON`

if [ ! -z $PHYLODIR/1A.txt ]; then mv $PHYLODIR/1A.txt $PHYLODIR/cellularity.predfile; fi
if [ ! -z $PHYLODIR/1B.txt ]; then mv $PHYLODIR/1B.txt $PHYLODIR/population.predfile; fi
if [ ! -z $PHYLODIR/1C.txt ]; then mv $PHYLODIR/1C.txt $PHYLODIR/proportion.predfile; fi
if [ ! -z $PHYLODIR/2A.txt ]; then mv $PHYLODIR/2A.txt $PHYLODIR/cluster_assignment.predfile; fi
if [ ! -z $PHYLODIR/2B.txt.gz ]; then mv $PHYLODIR/2B.txt.gz $PHYLODIR/cocluster_assignment.predfile; fi

tar -czf phyloWGS.tar.gz *predfile
rsync -a phyloWGS.tar.gz $OUTDIR

cd $ALPHA
rm -rf $WORKDIR*

