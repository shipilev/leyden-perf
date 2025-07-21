#/bin/bash

. setup.sh

# CPU config
CPUS=4
NODES=0-$(( $CPUS - 1 ))

# Config
HF_OPTS="-w 3 -r 10"
#HF_OPTS="-w 100 -r 500"

JP=~/trunks/jdk/build/proto-pp/

OUT=results/training-impact-single/
mkdir -p $OUT

OPTS="-XX:+UseParallelGC -Xms64m -Xmx1g"

rm -f *.aot *.aotconf
OPTS="$OPTS -cp JavacBenchApp.jar"
APP="JavacBenchApp "

#TIS="`seq 0 4`"
#RI=4

#TIS="`seq 0 4 20`"
#RI=10

#TIS="`seq 0 1 40`"
#RI=20

TIS="`seq 0 1 100`"
RI=50

#TIS="`seq 0 1 10` `seq 20 10 100`"
#TIS="`seq 0 1 10`"
#RI=5

if [ "x" == "x${GRAPH_ONLY}" ]; then
	taskset -c $NODES hyperfine $HF_OPTS "$J24/bin/java $OPTS $APP $RI" --export-csv $OUT/jdk24-base.csv

	for TI in $TIS; do
		rm -f *.aot *.aotconf
		$J24/bin/java -XX:AOTMode=record -XX:AOTConfiguration=app-$TI.aotconf $OPTS $APP $TI
		$J24/bin/java -XX:AOTMode=create -XX:AOTConfiguration=app-$TI.aotconf $OPTS -XX:AOTCache=app-$TI.aot
	        echo
		taskset -c $NODES hyperfine $HF_OPTS "$J24/bin/java -XX:AOTCache=app-$TI.aot $OPTS $APP $RI" --export-csv $OUT/jdk24-$TI.csv
	done



	taskset -c $NODES hyperfine $HF_OPTS "$JP/bin/java $OPTS $APP $RI" --export-csv $OUT/pp-base.csv

	for TI in $TIS; do
		rm -f *.aot *.aotconf
		$JP/bin/java -XX:AOTMode=record -XX:AOTConfiguration=app-$TI.aotconf $OPTS $APP $TI
		$JP/bin/java -XX:AOTMode=create -XX:AOTConfiguration=app-$TI.aotconf $OPTS -XX:AOTCache=app-$TI.aot
	        echo
		#taskset -c $NODES hyperfine $HF_OPTS "$JP/bin/java -XX:AOTCache=app-$TI.aot $OPTS -XX:+UnlockDiagnosticVMOptions -XX:+AOTCompileEagerly $APP $RI" --export-csv $OUT/pp-$TI.csv
		taskset -c $NODES hyperfine $HF_OPTS "$JP/bin/java -XX:AOTCache=app-$TI.aot $OPTS $APP $RI" --export-csv $OUT/pp-$TI.csv
	done


	taskset -c $NODES hyperfine $HF_OPTS "$JL/bin/java $OPTS $APP $RI" --export-csv $OUT/leyden-base.csv

	for TI in $TIS; do
		rm -f *.aot *.aotconf
		$JL/bin/java -XX:AOTMode=record -XX:AOTConfiguration=app-$TI.aotconf $OPTS $APP $TI
		$JL/bin/java -XX:AOTMode=create -XX:AOTConfiguration=app-$TI.aotconf $OPTS -XX:AOTCache=app-$TI.aot
	        echo
		taskset -c $NODES hyperfine $HF_OPTS "$JL/bin/java -XX:AOTCache=app-$TI.aot $OPTS $APP $RI" --export-csv $OUT/leyden-$TI.csv
	done
fi


rm *.dat
echo -n "-1," >> jdk24.dat
echo -n "-1," >> pp.dat
echo -n "-1," >> leyden.dat
cat $OUT/jdk24-base.csv    | tail -n 1 | cut -d, -f 2,3 >> jdk24.dat
cat $OUT/pp-base.csv | tail -n 1 | cut -d, -f 2,3 >> pp.dat
cat $OUT/leyden-base.csv   | tail -n 1 | cut -d, -f 2,3 >> leyden.dat

for TI in $TIS; do
	echo -n "$TI," >> jdk24.dat
	echo -n "$TI," >> pp.dat
	echo -n "$TI," >> leyden.dat
	cat $OUT/jdk24-$TI.csv    | tail -n 1 | cut -d, -f 2,3 >> jdk24.dat
	cat $OUT/pp-$TI.csv | tail -n 1 | cut -d, -f 2,3 >> pp.dat
	cat $OUT/leyden-$TI.csv   | tail -n 1 | cut -d, -f 2,3 >> leyden.dat
done

rm plot.gnu
cat <<EOF > plot.gnu
set datafile separator comma
set terminal png size 1600, 800
set output "$OUT/plot-$RI.png"

#set multiplot layout 2,1

set xrange [0:*]
set yrange [0:*]

#set log x

set ylabel "time, ms"
set xlabel "trained classes"

set key vert
set key top right
set key box
set key reverse Left

#set ytics 100
#set xtics 200000
set grid xtics ytics

set title "Javac Bench; Compiling $RI classes; $CPUS CPUs available"

plot "./jdk24.dat" using 1:(\$2*1000) lw 5 with lines title 'JDK 24 (Leyden 1/3: AOT class init)', \
     "./pp.dat" using 1:(\$2*1000) lw 5 with lines title 'JDK 25? (Leyden 2/3: + AOT profiling)', \
     "./leyden.dat" using 1:(\$2*1000) lw 5 with lines title 'JDK 26? (Leyden 3/3: + AOT compiled code)'

#plot "./jdk24.dat" using 1:(\$2*1000):(\$2-\$3)*1000:(\$2+\$3)*1000 lw 5 with errorbars title 'JDK 24 (Leyden 1/3: AOT class init)', \
#     "./pp.dat" using 1:(\$2*1000):(\$2-\$3)*1000:(\$2+\$3)*1000 lw 5 with errorbars title 'JDK 25? (Leyden 2/3: + AOT profiling)', \
#     "./leyden.dat" using 1:(\$2*1000):(\$2-\$3)*1000:(\$2+\$3)*1000 lw 5 with errorbars title 'JDK 26? (Leyden 3/3: + AOT compiled code)'
EOF

gnuplot plot.gnu
