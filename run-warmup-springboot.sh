#/bin/bash

. setup.sh

OUT=results/warmup-springboot/

mkdir -p $OUT

#OPTS="-XX:+UseParallelGC -Xmn7g -Xms8g -Xmx8g -XX:+AlwaysPreTouch -XX:SelfExitTimer=0.3 -jar ../spring-petclinic/target/spring-petclinic-2.1.0.BUILD-SNAPSHOT.jar -XX:GuaranteedSafepointInterval=1000"
OPTS="-XX:+UseParallelGC -Xmn7g -Xms8g -Xmx8g -XX:+AlwaysPreTouch -jar ../spring-petclinic/target/spring-petclinic-2.1.0.BUILD-SNAPSHOT.jar"
#OPTS="-XX:+UseSerialGC -Xms1g -Xmx1g -XX:+AlwaysPreTouch -Dspring.context.exit=onRefresh -XX:+UnlockDiagnosticVMOptions -XX:+UnlockExperimentalVMOptions -jar ../spring-petclinic/target/spring-petclinic-2.1.0.BUILD-SNAPSHOT.jar"

C=3
NODES=0-$C

#OPTS="$OPTS -XX:-TieredCompilation"
T_OPTS="$OPTS"
P_OPTS="$OPTS"

#P_OPTS="$OPTS -XX:+PreloadOnly"

SLEEP=10

T_REQ=10
P_REQ=10000

CONC=1

URL=http://localhost:8080/vets.html

if [ "x" == "x${GRAPH_ONLY}" ]; then
	rm $OUT/*.ssv

	# -- JDK 17

	taskset -c $NODES $J17/bin/java $P_OPTS &
        PID=$!
	sleep $SLEEP
	hey -o csv -c $CONC -n $P_REQ $URL > $OUT/jdk17.log
        kill $PID
        wait $PID

	# -- JDK 21

	taskset -c $NODES $J21/bin/java $P_OPTS &
        PID=$!
	sleep $SLEEP
	hey -o csv -c $CONC -n $P_REQ $URL > $OUT/jdk21.log
        kill $PID
        wait $PID

	# -- JDK 25

	taskset -c $NODES $J25/bin/java $P_OPTS &
        PID=$!
	sleep $SLEEP
	hey -o csv -c $CONC -n $P_REQ $URL > $OUT/jdk25.log
        kill $PID
        wait $PID

	# -- JDK 25 AOT
	rm -f *.aot *.aotconf

	$J25/bin/java -XX:AOTMode=record -XX:AOTConfiguration=app.aotconf $T_OPTS &
        PID=$!
	sleep $SLEEP
	hey -c $CONC -n $T_REQ $URL
        kill $PID
        wait $PID

	$J25/bin/java -XX:AOTMode=create -XX:AOTConfiguration=app.aotconf -XX:AOTCache=app.aot $T_OPTS

	taskset -c $NODES $J25/bin/java -XX:AOTCache=app.aot $P_OPTS &
        PID=$!
        sleep $SLEEP
	hey -o csv -c $CONC -n $P_REQ $URL > $OUT/jdk25-aot.log
        kill $PID
        wait $PID

	# --- Leyden
	rm -f *.aot *.aotconf

	$JL/bin/java -XX:AOTMode=record -XX:AOTConfiguration=app.aotconf $T_OPTS &
        PID=$!
	sleep $SLEEP
	hey -c $CONC -n $T_REQ $URL
        kill $PID
        wait $PID

	$JL/bin/java -XX:AOTMode=create -XX:AOTConfiguration=app.aotconf -XX:AOTCache=app.aot $T_OPTS

	taskset -c $NODES $JL/bin/java -XX:AOTCache=app.aot $P_OPTS &
        PID=$!
        sleep $SLEEP
	hey -o csv -c $CONC -n $P_REQ $URL > $OUT/premain.log
        kill $PID
        wait $PID

fi

rm plot.gnu

cat <<EOF > plot.gnu
set terminal png size 3200, 800
set output "$OUT/plot-t${TI}.png"
set datafile separator comma
set multiplot layout 1,4

set log y

set ylabel "response time, ms"
set xlabel "run time, sec"

set key vert
set key top left
set key box

#set ytics 100
#set xtics 200000
set grid xtics ytics mytics mxtics

set key top right
#set yrange [5:50]
unset xrange

set title "Spring Boot Petclinic; Trained $T_REQ Requests; $(( $C + 1 )) CPUs available"

plot "$OUT/jdk17.log" using (\$8+\$1):(\$1*1000) lw 5 with lines title 'JDK 17', \
     "$OUT/jdk21.log" using (\$8+\$1):(\$1*1000) lw 5 with lines title 'JDK 21', \
     "$OUT/jdk25.log" using (\$8+\$1):(\$1*1000) lw 5 with lines title 'JDK 25', \
     "$OUT/jdk25-aot.log" using (\$8+\$1):(\$1*1000) lw 5 with lines title 'JDK 25 (AOT)', \
     "$OUT/premain.log" using (\$8+\$1):(\$1*1000) lw 5 with lines title 'Leyden/premain'

set xrange [0:10]
replot

set xrange [0:5]
replot

set xrange [0:2]
replot


EOF

gnuplot plot.gnu
