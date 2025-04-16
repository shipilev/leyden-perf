#/bin/bash

. setup.sh

# Mainline
JT=$JM

# Custom build
#JT=/home/shade/trunks/jdk/build/linux-x86_64-server-release/images/jdk/

# CPU config
NODES=0-1

# Config
HF_OPTS="-w 5 -r 10"

OUT=results/training-impact/
mkdir -p $OUT

#ITERS="1 50 100 150 200 250 300 350 400 450 500 550 600 650 700 750 800 850 900 950 1000"
ITERS="1 2 4 8 16 32 64 128 256 512 1024 2048 4096 8192"

rm -f *.class *.jar
$J17/bin/javac JavacBenchApp.java
$J17/bin/jar cf JavacBenchApp.jar *.class

OPTS="-XX:+UseSerialGC -Xms64m -Xmx1g -cp JavacBenchApp.jar JavacBenchApp"

rm -f *.aot *.aotconf
for TI in $ITERS; do
	echo "Training with $TI iters..."
	$JT/bin/java -XX:AOTMode=record -XX:AOTConfiguration=app-$TI.aotconf $OPTS $TI
	$JT/bin/java -XX:AOTMode=create -XX:AOTConfiguration=app-$TI.aotconf -XX:AOTCache=app-$TI.aot $OPTS $TI
done

for RI in $ITERS; do
	echo "--- Running with $RI iters..."
        echo
	taskset -c $NODES hyperfine $HF_OPTS "$JT/bin/java $OPTS $RI"
	for TI in $ITERS; do
		taskset -c $NODES hyperfine $HF_OPTS "$JT/bin/java -XX:AOTCache=app-$TI.aot $OPTS $RI"
	done
done
