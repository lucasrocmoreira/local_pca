#!/bin/bash

NAME="local_strong"
TAG=$(printf "%06d" $RANDOM); 
DIR="${NAME}_${TAG}"
mkdir -p $DIR
echo "Directory: $DIR"
BASE_PARAMS="-n 1 -j 1 -k 2000 -w 10 -m 1e-3 -u 0.0 -o $DIR -N 1000"
# MORE_PARAMS=("-m 0.5e-3" "-m 0.5e-3" "-m 0.5e-3" "-m 0.75e-3" "-m 0.75e-3" "-m 0.75e-3" "-m 1.5e-3" "-m 1.5e-3" "-m 1.5e-3" "-m 5e-3" "-m 5e-3" "-m 5e-3")
MORE_PARAMS=("-m 0.75e-3" "-m 1.5e-3" "-m 1.5e-3" "-m 1.5e-3" "-m 5e-3" "-m 5e-3" "-m 5e-3")
NPARAMS=${#MORE_PARAMS[@]}
echo "$NPARAMS chromosomes."
for CHROM_NUM in $(seq $((NPARAMS)))
do
    echo "Chrom $CHROM_NUM"
    export PARAMS="$BASE_PARAMS ${MORE_PARAMS[$((CHROM_NUM-1))]} -C $CHROM_NUM"
    sbatch -o $DIR/run_${CHROM_NUM}.out -e $DIR/run_${CHROM_NUM}.out ./run-sim.sbatch 
done
