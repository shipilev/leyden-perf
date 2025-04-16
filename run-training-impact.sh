#/bin/bash

. setup.sh

# Mainline
#JT=$JM
#OUT=results/training-impact/mainline

# Leyden
JT=$JL
OUT=results/training-impact/leyden

# Custom build
#JT=/home/shade/trunks/jdk/build/linux-x86_64-server-release/images/jdk/

OUT=results/training-impact/leyden

# CPU config
NODES=0-1

# Config
HF_OPTS="-w 3 -r 3"

mkdir -p $OUT

#ITERS="1 50 100 150 200 250 300 350 400 450 500 550 600 650 700 750 800 850 900 950 1000"
#ITERS="1 2 4 8 16 32 64 128 256 512 1024 2048 4096 8192"
#ITERS="1 2 4 8 16 32 64 128 256 512 1024"
ITERS="1 2 4 8 16 32 64 128"

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
	taskset -c $NODES hyperfine $HF_OPTS "$JT/bin/java $OPTS $RI" --export-csv $OUT/0-$RI.csv
	for TI in $ITERS; do
		taskset -c $NODES hyperfine $HF_OPTS "$JT/bin/java -XX:AOTCache=app-$TI.aot $OPTS $RI" --export-csv $OUT/$TI-$RI.csv
	done
done

for RI in $ITERS; do
DATA=data-$RI.dat
BASE=base-data-$RI.dat
rm $DATA $BASE
for TI in $ITERS; do
	echo -n "$TI," >> $DATA
	cat $OUT/$TI-$RI.csv | tail -n 1 | cut -d, -f 2,3 >> $DATA
	echo -n "$TI," >> $BASE
	cat $OUT/0-$RI.csv | tail -n 1 | cut -d, -f 2,3 >> $BASE
done

done

cat base-data-1.dat
cat data-1.dat

rm plot.gnu
cat <<EOF > plot.gnu
set datafile separator comma
set terminal png size 2000, 2400
set output "plot.png"

set multiplot layout 4,3

#set xrange [0:1024]
#set yrange [0:*]

set log x

set ylabel "time, ms"
set xlabel "training duration"

set key horiz
set key top left
set key box 

#set ytics 100
#set xtics 200000
set grid xtics ytics

set title ""
EOF

for TI in $ITERS; do
cat <<EOF >> plot.gnu
plot "./base-data-$TI.dat" using 1:(\$2*1000) lw 5 with lines title 'no AOT', \
     "./data-$TI.dat" using 1:(\$2*1000):(\$2-\$3)*1000:(\$2+\$3)*1000 lw 5 with errorbars title 'AOT'
EOF
done

gnuplot plot.gnu
