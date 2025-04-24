#/bin/bash

. setup.sh

JM=~/trunks/jdk/build/baseline-pp/
JP=~/trunks/jdk/build/proto-pp/
#JP=~/trunks/jdk/build/linux-x86_64-server-release/images/jdk/

OUT=results/warmup-curve/

#CORE_LIST="3 7 15"
CORE_LIST="0 1 3 7 15 31"

mkdir -p $OUT

rm -f *.class *.$OUT/jar
$J17/bin/javac JavacBenchApp.java
$J17/bin/jar cf JavacBenchApp.jar *.class

TI=$1

if [ "x" == "x${TI}" ]; then
  TI=100
fi

RI=500

SHOW_ITERS=50

#OPTS="-XX:+UseParallelGC -Xmn7g -Xms8g -Xmx8g -XX:+AlwaysPreTouch -XX:-TieredCompilation -cp JavacBenchApp.jar JavacBenchApp"
OPTS="-XX:+UseParallelGC -Xmn7g -Xms8g -Xmx8g -XX:+AlwaysPreTouch -cp JavacBenchApp.jar JavacBenchApp"

if [ "x" == "x${GRAPH_ONLY}" ]; then
	rm $OUT/*.ssv

	rm -f *.aot *.aotconf
	for C in $CORE_LIST; do
		taskset -c 0-$C $JM/bin/java $OPTS $RI >> $OUT/mainline-$C.ssv
	done

	rm -f *.aot *.aotconf
	$JM/bin/java -XX:AOTMode=record -XX:AOTConfiguration=app.aotconf $OPTS $TI
	$JM/bin/java -XX:AOTMode=create -XX:AOTConfiguration=app.aotconf -XX:AOTCache=app.aot $OPTS $TI
	for C in $CORE_LIST; do
		taskset -c 0-$C $JM/bin/java -XX:AOTCache=app.aot $OPTS $RI >> $OUT/mainline-aot-$C.ssv
	done

	rm -f *.aot *.aotconf
	$JL/bin/java -XX:AOTMode=record -XX:AOTConfiguration=app.aotconf $OPTS $TI
	$JL/bin/java -XX:AOTMode=create -XX:AOTConfiguration=app.aotconf -XX:AOTCache=app.aot $OPTS $TI
	for C in $CORE_LIST; do
		taskset -c 0-$C $JL/bin/java -XX:AOTCache=app.aot $OPTS $RI >> $OUT/premain-$C.ssv
	done

	rm -f *.aot *.aotconf
	$JP/bin/java -XX:AOTMode=record -XX:AOTConfiguration=app.aotconf $OPTS $TI
	$JP/bin/java -XX:AOTMode=create -XX:AOTConfiguration=app.aotconf -XX:AOTCache=app.aot $OPTS $TI
	for C in $CORE_LIST; do
		taskset -c 0-$C $JP/bin/java -XX:AOTCache=app.aot $OPTS $RI >> $OUT/pp-$C.ssv
		taskset -c 0-$C $JP/bin/java -XX:AOTCache=app.aot -XX:+UnlockDiagnosticVMOptions -XX:+UseNewCode $OPTS $RI >> $OUT/pp-nocomp-$C.ssv
	done
fi

rm plot.gnu
cat <<EOF > plot.gnu
set terminal png size 1600, 3200
set output "$OUT/plot-t${TI}.png"

set multiplot layout 6,2

set key vert
set key box

#set ytics 100
#set xtics 200000
set grid xtics ytics mytics mxtics
EOF


for C in $CORE_LIST; do

cat <<EOF >> plot.gnu
set xlabel "run time, ms"
set ylabel "time per class, ms"
set key top right

set title "Trained $TI Classes; First $SHOW_ITERS Classes Shown; $(( $C + 1 )) CPUs available"
set xrange [-2:2000]
set yrange [0:*]
unset yrange
plot "$OUT/mainline-$C.ssv" using 2:(\$3/1000) lw 5 with lines title 'Mainline', \
     "$OUT/mainline-aot-$C.ssv" using 2:(\$3/1000) lw 5 with lines title 'Mainline AOT', \
     "$OUT/premain-$C.ssv" using 2:(\$3/1000) lw 5 with lines title 'Premain AOT', \
     "$OUT/pp-$C.ssv" using 2:(\$3/1000) lw 5 with lines title 'Pers Prof', \
     "$OUT/pp-nocomp-$C.ssv" using 2:(\$3/1000) lw 5 with lines title 'Pers Prof (No Comp)'

set title "Trained $TI Classes; All Data Shown; $(( $C + 1 )) CPUs available"
unset xrange
set yrange [5:*]
set log y
replot
unset log y
EOF
done

gnuplot plot.gnu
