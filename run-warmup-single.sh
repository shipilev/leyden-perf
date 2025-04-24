#/bin/bash

. setup.sh

JP=~/trunks/shipilev-leyden/build/linux-x86_64-server-release/images/jdk/

OUT=results/warmup-single/

mkdir -p $OUT

rm -f *.class *.$OUT/jar
$J17/bin/javac JavacBenchApp.java
$J17/bin/jar cf JavacBenchApp.jar *.class

TI=1000
RI=1000

SHOW_ITERS=2000

#OPTS="-XX:+UseParallelGC -Xmn7g -Xms8g -Xmx8g -XX:+AlwaysPreTouch -XX:-Inline -XX:-TieredCompilation -cp JavacBenchApp.jar JavacBenchApp"
OPTS="-XX:+UseParallelGC -Xmn7g -Xms8g -Xmx8g -XX:+AlwaysPreTouch -cp JavacBenchApp.jar JavacBenchApp"
PP_OPTS="-XX:+UnlockDiagnosticVMOptions -XX:+AbortVMOnCompilationFailure -XX:-UseNewCode $OPTS"
PP2_OPTS="-XX:+UnlockDiagnosticVMOptions -XX:+AbortVMOnCompilationFailure -XX:+UseNewCode $OPTS"
PP3_OPTS="-XX:+UnlockDiagnosticVMOptions -XX:+AbortVMOnCompilationFailure -XX:-AOTReplayTraining $OPTS"


C=3
NODES=0-$C

if [ "x" == "x${GRAPH_ONLY}" ]; then
	rm $OUT/*.ssv
	rm -f *.aot *.aotconf
	$JL/bin/java -XX:AOTMode=record -XX:AOTConfiguration=app.aotconf $OPTS $TI
	$JL/bin/java -XX:AOTMode=create -XX:AOTConfiguration=app.aotconf -XX:AOTCache=app.aot $OPTS $TI
	taskset -c $NODES $JL/bin/java -XX:AOTCache=app.aot $OPTS $RI >> $OUT/premain-$C.ssv

	rm -f *.aot *.aotconf
	$JP/bin/java -XX:AOTMode=record -XX:AOTConfiguration=app.aotconf $OPTS $TI
	$JP/bin/java -XX:AOTMode=create -XX:AOTConfiguration=app.aotconf -XX:AOTCache=app.aot $OPTS $TI
	taskset -c $NODES $JP/bin/java -XX:AOTCache=app.aot $PP_OPTS $RI >> $OUT/fix-$C.ssv
fi

rm plot.gnu
cat <<EOF > plot.gnu
set terminal png size 1600, 800
set output "$OUT/plot-t${TI}.png"

set multiplot layout 1,2

#set log y

set ylabel "time per class, ms"
set xlabel "run time, ms"

set key vert
set key top left
set key box

#set ytics 100
#set xtics 200000
set grid xtics ytics mytics mxtics

EOF


cat <<EOF >> plot.gnu
set title "Trained $TI Classes; First $SHOW_ITERS Shown; $(( $C + 1 )) CPUs Available"

#set arrow from $TI, graph 0 to $TI, graph 1 nohead lc rgb 'red' lw 5

set key top right
set yrange [5:50]
set xrange [-2:$SHOW_ITERS]
plot "$OUT/premain-$C.ssv" using 2:(\$3/1000) lw 5 with lines title 'Current premain', \
     "$OUT/fix-$C.ssv" using 2:(\$3/1000) lw 5 with lines title 'Fixed', \

set title "Trained $TI Classes; All Shown; $(( $C + 1 )) CPUs Available"
unset xrange
replot
EOF

gnuplot plot.gnu
