#/bin/bash

. setup.sh

#JM=~/trunks/jdk/build/baseline-pp/
#JP=~/trunks/jdk/build/proto-pp/
#JP=~/trunks/jdk/build/linux-x86_64-server-release/images/jdk/

OUT=results/warmup-hellostream/

#CORE_LIST="3 7 15"
CORE_LIST="0 1 3 7 15 31"

mkdir -p $OUT

rm -f *.class *.$OUT/jar
$J17/bin/javac HelloStreamIters.java

TI=$1

if [ "x" == "x${TI}" ]; then
  TI=10000
fi

RI=100000

OPTS="-Xms128m -Xmx128m -XX:+AlwaysPreTouch HelloStreamIters"

if [ "x" == "x${GRAPH_ONLY}" ]; then
	rm $OUT/*.ssv

	rm -f *.aot *.aotconf
	for C in $CORE_LIST; do
		taskset -c 0-$C $J25/bin/java $OPTS $RI >> $OUT/jdk25-$C.ssv
	done

	rm -f *.aot *.aotconf
	$J25/bin/java -XX:AOTCacheOutput=app.aot $OPTS $TI
	for C in $CORE_LIST; do
		taskset -c 0-$C $J25/bin/java -XX:AOTCache=app.aot $OPTS $RI >> $OUT/jdk25-aot-$C.ssv
		taskset -c 0-$C $J25/bin/java -XX:AOTCache=app.aot -XX:+UnlockDiagnosticVMOptions -XX:-AOTReplayTraining $OPTS $RI >> $OUT/jdk25-aot-norp-$C.ssv
	done

#	rm -f *.aot *.aotconf
#	for C in $CORE_LIST; do
#		taskset -c 0-$C $JM/bin/java $OPTS $RI >> $OUT/mainline-$C.ssv
#	done

#	rm -f *.aot *.aotconf
#	$JM/bin/java -XX:AOTCacheOutput=app.aot $OPTS $TI
#	for C in $CORE_LIST; do
#		taskset -c 0-$C $JM/bin/java -XX:AOTCache=app.aot $OPTS $RI >> $OUT/mainline-aot-$C.ssv
#	done
fi

rm plot.gnu
cat <<EOF > plot.gnu
set terminal png size 2400, 1600
set output "$OUT/plot-t${TI}.png"
set palette viridis

set multiplot layout 3,2

set key vert
set key box

#set ytics 100
#set xtics 200000
set grid xtics ytics mytics mxtics
EOF


for C in $CORE_LIST; do

cat <<EOF >> plot.gnu
set xlabel "run time, ms"
set ylabel "time per invoke, us"
set key top right

set title "Trained $TI Invokes; $(( $C + 1 )) CPUs available"
#set xrange [-2:2000]
#set yrange [0:*]
#unset yrange
set log y

plot \
     "$OUT/jdk25-$C.ssv"        using (\$1/1000000):(\$2/1000) title 'JDK 25', \
     "$OUT/jdk25-aot-$C.ssv"    using (\$1/1000000):(\$2/1000)  title 'JDK 25 (AOT)', \
     "$OUT/jdk25-aot-norp-$C.ssv"    using (\$1/1000000):(\$2/1000) title 'JDK 25 (AOT, no replay)'
EOF
done

gnuplot plot.gnu
