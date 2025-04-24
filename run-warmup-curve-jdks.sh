#/bin/bash

. setup.sh

JM=~/trunks/jdk/build/baseline-pp/
JP=~/trunks/jdk/build/proto-pp/
#JP=~/trunks/jdk/build/linux-x86_64-server-release/images/jdk/

OUT=results/warmup-curve-jdks/

C=15

mkdir -p $OUT

rm -f *.class *.$OUT/jar
$J17/bin/javac JavacBenchApp.java
$J17/bin/jar cf JavacBenchApp.jar *.class

TI=1000
RI=1000

OPTS="-XX:+UseParallelGC -Xmn7g -Xms8g -Xmx8g -XX:+AlwaysPreTouch -cp JavacBenchApp.jar JavacBenchApp"
C1_OPTS="-XX:TieredStopAtLevel=1 $OPTS"
C2_OPTS="-XX:-TieredCompilation $OPTS"


if [ "x" == "x${GRAPH_ONLY}" ]; then
	rm $OUT/*.ssv

	taskset -c 0-$C $J17/bin/java $OPTS $RI >> $OUT/jdk17-$C.ssv
	taskset -c 0-$C $J17/bin/java $C1_OPTS $RI >> $OUT/jdk17-c1-$C.ssv
	taskset -c 0-$C $J17/bin/java $C2_OPTS $RI >> $OUT/jdk17-c2-$C.ssv

	taskset -c 0-$C $J21/bin/java $OPTS $RI >> $OUT/jdk21-$C.ssv
	taskset -c 0-$C $J21/bin/java $C1_OPTS $RI >> $OUT/jdk21-c1-$C.ssv
	taskset -c 0-$C $J21/bin/java $C2_OPTS $RI >> $OUT/jdk21-c2-$C.ssv

	rm -f *.aot *.aotconf
	$J24/bin/java -XX:AOTMode=record -XX:AOTConfiguration=app.aotconf $OPTS $TI
	$J24/bin/java -XX:AOTMode=create -XX:AOTConfiguration=app.aotconf -XX:AOTCache=app.aot $OPTS $TI
	taskset -c 0-$C $J24/bin/java -XX:AOTCache=app.aot $OPTS $RI >> $OUT/jdk24-aot-$C.ssv

	rm -f *.aot *.aotconf
	$J24/bin/java -XX:AOTMode=record -XX:AOTConfiguration=app.aotconf $C1_OPTS $TI
	$J24/bin/java -XX:AOTMode=create -XX:AOTConfiguration=app.aotconf -XX:AOTCache=app.aot $C1_OPTS $TI
	taskset -c 0-$C $J24/bin/java -XX:AOTCache=app.aot $C1_OPTS $RI >> $OUT/jdk24-aot-c1-$C.ssv

	rm -f *.aot *.aotconf
	$J24/bin/java -XX:AOTMode=record -XX:AOTConfiguration=app.aotconf $C2_OPTS $TI
	$J24/bin/java -XX:AOTMode=create -XX:AOTConfiguration=app.aotconf -XX:AOTCache=app.aot $C2_OPTS $TI
	taskset -c 0-$C $J24/bin/java -XX:AOTCache=app.aot $C2_OPTS $RI >> $OUT/jdk24-aot-c2-$C.ssv

	rm -f *.aot *.aotconf
	$JP/bin/java -XX:AOTMode=record -XX:AOTConfiguration=app.aotconf $OPTS $TI
	$JP/bin/java -XX:AOTMode=create -XX:AOTConfiguration=app.aotconf -XX:AOTCache=app.aot $OPTS $TI
	taskset -c 0-$C $JP/bin/java -XX:AOTCache=app.aot -XX:+UnlockDiagnosticVMOptions -XX:+UseNewCode -XX:+UseNewCode2 $OPTS $RI >> $OUT/jdk25-aot-$C.ssv

	rm -f *.aot *.aotconf
	$JP/bin/java -XX:AOTMode=record -XX:AOTConfiguration=app.aotconf $C1_OPTS $TI
	$JP/bin/java -XX:AOTMode=create -XX:AOTConfiguration=app.aotconf -XX:AOTCache=app.aot $C1_OPTS $TI
	taskset -c 0-$C $JP/bin/java -XX:AOTCache=app.aot -XX:+UnlockDiagnosticVMOptions -XX:+UseNewCode -XX:+UseNewCode2 $C1_OPTS $RI >> $OUT/jdk25-aot-c1-$C.ssv

	rm -f *.aot *.aotconf
	$JP/bin/java -XX:AOTMode=record -XX:AOTConfiguration=app.aotconf $C2_OPTS $TI
	$JP/bin/java -XX:AOTMode=create -XX:AOTConfiguration=app.aotconf -XX:AOTCache=app.aot $C2_OPTS $TI
	taskset -c 0-$C $JP/bin/java -XX:AOTCache=app.aot -XX:+UnlockDiagnosticVMOptions -XX:+UseNewCode -XX:+UseNewCode2 $C2_OPTS $RI >> $OUT/jdk25-aot-c2-$C.ssv

	rm -f *.aot *.aotconf
	$JL/bin/java -XX:AOTMode=record -XX:AOTConfiguration=app.aotconf $OPTS $TI
	$JL/bin/java -XX:AOTMode=create -XX:AOTConfiguration=app.aotconf -XX:AOTCache=app.aot $OPTS $TI
	taskset -c 0-$C $JL/bin/java -XX:AOTCache=app.aot $OPTS $RI >> $OUT/jdk26-aot-$C.ssv

	rm -f *.aot *.aotconf
	$JL/bin/java -XX:AOTMode=record -XX:AOTConfiguration=app.aotconf $C1_OPTS $TI
	$JL/bin/java -XX:AOTMode=create -XX:AOTConfiguration=app.aotconf -XX:AOTCache=app.aot $C1_OPTS $TI
	taskset -c 0-$C $JL/bin/java -XX:AOTCache=app.aot $C1_OPTS $RI >> $OUT/jdk26-aot-c1-$C.ssv

	rm -f *.aot *.aotconf
	$JL/bin/java -XX:AOTMode=record -XX:AOTConfiguration=app.aotconf $C2_OPTS $TI
	$JL/bin/java -XX:AOTMode=create -XX:AOTConfiguration=app.aotconf -XX:AOTCache=app.aot $C2_OPTS $TI
	taskset -c 0-$C $JL/bin/java -XX:AOTCache=app.aot $C2_OPTS $RI >> $OUT/jdk26-aot-c2-$C.ssv
fi

rm plot.gnu
cat <<EOF > plot.gnu
set terminal png size 1600, 1600
set output "$OUT/plot-t${TI}.png"

set multiplot layout 3,2

set log y

set key vert
set key box
set key top right
set key reverse Left

set xlabel "run time, ms"
set ylabel "time per compilation, ms"

#set ytics 100
#set xtics 100
set grid xtics ytics mytics mxtics

#set xrange [-2:000]

set xrange [0:2000]
set yrange [0:300]
unset log y

set title "Javac Bench; Trained $TI Classes; $(( $C + 1 )) CPUs available"
plot "$OUT/jdk17-$C.ssv" using 2:(\$3/1000) lw 5 with lines title 'JDK 17', \
     "$OUT/jdk21-$C.ssv" using 2:(\$3/1000) lw 5 with lines title 'JDK 21', \
     "$OUT/jdk24-aot-$C.ssv" using 2:(\$3/1000) lw 5 with lines title 'JDK 24 (Leyden 1/3: AOT class init)', \
     "$OUT/jdk25-aot-$C.ssv" using 2:(\$3/1000) lw 5 with lines title 'JDK 25? (Leyden 2/3: + AOT profiling)', \
     "$OUT/jdk26-aot-$C.ssv" using 2:(\$3/1000) lw 5 with lines title 'JDK 26? (Leyden 3/3: + AOT compiled code)'

unset xrange
set yrange [7:300]
set log y
replot
set xrange [0:2000]
set yrange [0:300]
unset log y

set title "Javac Bench; Trained $TI Classes; $(( $C + 1 )) CPUs available; C1 only"
plot "$OUT/jdk17-c1-$C.ssv" using 2:(\$3/1000) lw 5 with lines title 'JDK 17', \
     "$OUT/jdk21-c1-$C.ssv" using 2:(\$3/1000) lw 5 with lines title 'JDK 21', \
     "$OUT/jdk24-aot-c1-$C.ssv" using 2:(\$3/1000) lw 5 with lines title 'JDK 24 (Leyden 1/3: AOT class init)', \
     "$OUT/jdk25-aot-c1-$C.ssv" using 2:(\$3/1000) lw 5 with lines title 'JDK 25? (Leyden 2/3: + AOT profiling)', \
     "$OUT/jdk26-aot-c1-$C.ssv" using 2:(\$3/1000) lw 5 with lines title 'JDK 26? (Leyden 3/3: + AOT compiled code)'

unset xrange
set yrange [7:300]
set log y
replot
set xrange [0:2000]
set yrange [0:300]
unset log y

set title "Javac Bench; Trained $TI Classes; $(( $C + 1 )) CPUs available; C2 only"
plot "$OUT/jdk17-c2-$C.ssv" using 2:(\$3/1000) lw 5 with lines title 'JDK 17', \
     "$OUT/jdk21-c2-$C.ssv" using 2:(\$3/1000) lw 5 with lines title 'JDK 21', \
     "$OUT/jdk24-aot-c2-$C.ssv" using 2:(\$3/1000) lw 5 with lines title 'JDK 24 (Leyden 1/3: AOT class init)', \
     "$OUT/jdk25-aot-c2-$C.ssv" using 2:(\$3/1000) lw 5 with lines title 'JDK 25? (Leyden 2/3: + AOT profiling)', \
     "$OUT/jdk26-aot-c2-$C.ssv" using 2:(\$3/1000) lw 5 with lines title 'JDK 26? (Leyden 3/3: + AOT compiled code)'

unset xrange
set yrange [7:300]
set log y
replot
set xrange [0:2000]
set yrange [0:300]
unset log y

EOF

gnuplot plot.gnu
