#/bin/bash

. setup.sh

#JP=~/trunks/shipilev-leyden/build/linux-x86_64-server-fastdebug/images/jdk/
JP=~/trunks/shipilev-leyden/build/linux-x86_64-server-release/images/jdk/

OUT=results/warmup-springboot/

mkdir -p $OUT

#OPTS="-XX:+UseParallelGC -Xmn7g -Xms8g -Xmx8g -XX:+AlwaysPreTouch -XX:SelfExitTimer=0.3 -jar ../spring-petclinic/target/spring-petclinic-2.1.0.BUILD-SNAPSHOT.jar -XX:GuaranteedSafepointInterval=1000"
OPTS="-XX:+UseSerialGC -Xms1g -Xmx1g -XX:+AlwaysPreTouch -Dspring.context.exit=onRefresh -XX:+UnlockDiagnosticVMOptions -XX:+UnlockExperimentalVMOptions -jar ../spring-petclinic/target/spring-petclinic-2.1.0.BUILD-SNAPSHOT.jar"

C=0
NODES=0-$C

#OPTS="$OPTS -XX:-TieredCompilation"
T_OPTS="$OPTS"
P_OPTS="$OPTS"

#P_OPTS="$OPTS -XX:+PreloadOnly"

SLEEP=30

ITERS=100
RATE=600

if [ "x" == "x${GRAPH_ONLY}" ]; then
	rm $OUT/*.ssv
	rm -f *.aot *.aotconf

	taskset -c $NODES $JP/bin/java $P_OPTS &
        PID=$!
	sleep $SLEEP
        for I in `seq 1 $ITERS`; do wrk2 -R $RATE -d 1 http://127.0.0.1:8080/ 2>&1 | grep Latency; done | nl 2>&1 | tee $OUT/mainline.log
        kill $PID
        wait $PID


	$JP/bin/java -XX:AOTMode=record -XX:AOTConfiguration=app.aotconf $T_OPTS &
        PID=$!
	sleep $SLEEP
        for I in `seq 1 $ITERS`; do wrk2 -R $RATE -d 1 http://127.0.0.1:8080/ 2>&1 | grep Latency; done | nl
        kill $PID
        wait $PID

	$JP/bin/java -XX:AOTMode=create -XX:AOTConfiguration=app.aotconf -XX:AOTCache=app.aot $T_OPTS

	taskset -c $NODES $JP/bin/java -XX:AOTCache=app.aot $P_OPTS &
        PID=$!
        sleep $SLEEP
        for I in `seq 1 $ITERS`; do wrk2 -R $RATE -d 1 http://127.0.0.1:8080/ 2>&1 | grep Latency; done | nl 2>&1 | tee $OUT/leyden.log
        kill $PID
        wait $PID

#	taskset -c $NODES $JP/bin/java -XX:AOTCache=app.aot $P_OPTS -XX:-AOTCompileEagerly &
#        PID=$!
#       sleep $SLEEP
#        for I in `seq 1 $ITERS`; do wrk2 -R $RATE -d 1 http://127.0.0.1:8080/ 2>&1 | grep Latency; done | nl 2>&1 | tee $OUT/leyden-nocomp.log
#        kill $PID
#        wait $PID

#	rm -f *.aot *.aotconf
#	$JP/bin/java -XX:AOTMode=record -XX:AOTConfiguration=app.aotconf $OPTS $TI
#	$JP/bin/java -XX:AOTMode=create -XX:AOTConfiguration=app.aotconf -XX:AOTCache=app.aot $OPTS $TI
#	taskset -c $NODES $JP/bin/java -XX:AOTCache=app.aot $PP_OPTS $RI >> $OUT/fix-$C.ssv
fi

exit

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
