#/bin/bash

. setup.sh

JM=~/trunks/jdk/build/baseline-pp/
JP=~/trunks/jdk/build/linux-x86_64-server-release/images/jdk/

OUT=results/warmup-single/

#CORE_LIST="0 1 3"
CORE_LIST="0 1 3 7 15 31"

mkdir -p $OUT

rm -f *.class *.$OUT/jar
$J17/bin/javac JavacBenchApp.java
$J17/bin/jar cf JavacBenchApp.jar *.class

TI=1000
RI=1000

SHOW_ITERS=50

#OPTS="-XX:+UseParallelGC -Xmn7g -Xms8g -Xmx8g -XX:+AlwaysPreTouch -XX:-Inline -XX:-TieredCompilation -cp JavacBenchApp.jar JavacBenchApp"
OPTS="-XX:+UseParallelGC -Xmn7g -Xms8g -Xmx8g -XX:+AlwaysPreTouch -cp JavacBenchApp.jar JavacBenchApp"
PP_OPTS="-XX:+UnlockDiagnosticVMOptions -XX:+AbortVMOnCompilationFailure -XX:-UseNewCode $OPTS"
PP2_OPTS="-XX:+UnlockDiagnosticVMOptions -XX:+AbortVMOnCompilationFailure -XX:+UseNewCode -XX:+UseNewCode2 $OPTS"
PP3_OPTS="-XX:+UnlockDiagnosticVMOptions -XX:+AbortVMOnCompilationFailure -XX:+UseNewCode -XX:-ReplayTraining $OPTS"


C=15
NODES=0-$C

if [ "x" == "x${GRAPH_ONLY}" ]; then
	rm $OUT/*.ssv
	rm -f *.aot *.aotconf
	$JM/bin/java -XX:AOTMode=record -XX:AOTConfiguration=app.aotconf $OPTS $TI
	$JM/bin/java -XX:AOTMode=create -XX:AOTConfiguration=app.aotconf -XX:AOTCache=app.aot $OPTS $TI
	taskset -c $NODES $JM/bin/java -XX:AOTCache=app.aot $OPTS $RI >> $OUT/mainline-aot-$C.ssv

	rm -f *.aot *.aotconf
	$JP/bin/java -XX:AOTMode=record -XX:AOTConfiguration=app.aotconf $OPTS $TI
	$JP/bin/java -XX:AOTMode=create -XX:AOTConfiguration=app.aotconf -XX:AOTCache=app.aot $OPTS $TI
	taskset -c $NODES $JP/bin/java -XX:AOTCache=app.aot $PP_OPTS $RI >> $OUT/pp-$C.ssv
	taskset -c $NODES $JP/bin/java -XX:AOTCache=app.aot $PP2_OPTS $RI >> $OUT/pp-nocomp-$C.ssv
	taskset -c $NODES $JP/bin/java -XX:AOTCache=app.aot $PP3_OPTS $RI >> $OUT/pp-noreplay-$C.ssv

#	taskset -c $NODES $JP/bin/java -XX:AOTCache=app.aot -XX:+UnlockDiagnosticVMOptions -XX:+UseNewCode -XX:+UseNewCode2 -XX:+PrintTieredEvents $OPTS $RI
fi

rm plot.gnu
cat <<EOF > plot.gnu
set terminal png size 3200, 800
set output "$OUT/plot-t${TI}.png"

set multiplot layout 1,4

#set log y

set xlabel "iteration"

set key vert
set key top left
set key box

#set ytics 100
#set xtics 200000
set grid xtics ytics mytics mxtics

EOF


cat <<EOF >> plot.gnu
set title "Trained $TI Iterations; First $SHOW_ITERS Iterations Shown; CPUs: $(( $C + 1 ))"

#set arrow from $TI, graph 0 to $TI, graph 1 nohead lc rgb 'red' lw 5

set key top right
set yrange [5:50]
set xrange [-2:$SHOW_ITERS]
set ylabel "time per iteration, ms"
plot "$OUT/mainline-aot-$C.ssv" using 1:(\$3/1000) lw 5 with lines title 'Mainline AOT', \
     "$OUT/pp-$C.ssv" using 1:(\$3/1000) lw 5 with lines title 'Pers Prof', \
     "$OUT/pp-nocomp-$C.ssv" using 1:(\$3/1000) lw 5 with lines title 'Pers Prof (No comp)', \
     "$OUT/pp-noreplay-$C.ssv" using 1:(\$3/1000) lw 5 with lines title 'Pers Prof (No comp, no replay)', \

set title "Trained $TI Iterations; All Iterations Shown; CPUs: $(( $C + 1 ))"
unset xrange
plot "$OUT/mainline-aot-$C.ssv" using 1:(\$3/1000) lw 5 with lines title 'Mainline AOT', \
     "$OUT/pp-$C.ssv" using 1:(\$3/1000) lw 5 with lines title 'Pers Prof', \
     "$OUT/pp-nocomp-$C.ssv" using 1:(\$3/1000) lw 5 with lines title 'Pers Prof (No comp)', \
     "$OUT/pp-noreplay-$C.ssv" using 1:(\$3/1000) lw 5 with lines title 'Pers Prof (No comp, no replay)'

set key bottom right
set title "Trained $TI Iterations; First $SHOW_ITERS Iterations Shown, Integrated; CPUs: $(( $C + 1 ))"
set xrange [-2:$SHOW_ITERS]
unset yrange
set ylabel "cumulative time, ms"
plot "$OUT/mainline-aot-$C.ssv" using 1:2 lw 5 with lines title 'Mainline AOT', \
     "$OUT/pp-$C.ssv" using 1:2 lw 5 with lines title 'Pers Prof', \
     "$OUT/pp-nocomp-$C.ssv" using 1:2 lw 5 with lines title 'Pers Prof (No comp)', \
     "$OUT/pp-noreplay-$C.ssv" using 1:2 lw 5 with lines title 'Pers Prof (No comp, no replay)'

set title "Trained $TI Iterations; All Iterations Shown, Integrated; CPUs: $(( $C + 1 ))"
unset xrange
unset yrange
set ylabel "cumulative time, ms"
plot "$OUT/mainline-aot-$C.ssv" using 1:2 lw 5 with lines title 'Mainline AOT', \
     "$OUT/pp-$C.ssv" using 1:2 lw 5 with lines title 'Pers Prof', \
     "$OUT/pp-nocomp-$C.ssv" using 1:2 lw 5 with lines title 'Pers Prof (No comp)', \
     "$OUT/pp-noreplay-$C.ssv" using 1:2 lw 5 with lines title 'Pers Prof (No comp, no replay)'
EOF

gnuplot plot.gnu
