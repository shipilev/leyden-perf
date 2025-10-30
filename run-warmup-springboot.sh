#/bin/bash

. setup.sh

OUT=`pwd`/results/warmup-springboot/

mkdir -p $OUT

#OPTS="-XX:+UseParallelGC -Xmn7g -Xms8g -Xmx8g -XX:+AlwaysPreTouch -XX:SelfExitTimer=0.3 -jar ../spring-petclinic/target/spring-petclinic-2.1.0.BUILD-SNAPSHOT.jar -XX:GuaranteedSafepointInterval=1000"
#OPTS="-XX:+UseParallelGC -Xmn7g -Xms8g -Xmx8g -XX:+AlwaysPreTouch -Dspring.aot.enabled=true -Dspring.output.ansi.enabled=NEVER -cp @/home/shade/trunks/shipilev-leyden/test/hotspot/jtreg/premain/spring-petclinic/petclinic-snapshot-warmup/target/unpacked/classpath org.springframework.samples.petclinic.PetClinicApplication"
OPTS="-Xms1g -Xmx1g -XX:+AlwaysPreTouch -jar `pwd`/../spring-petclinic/target/spring-petclinic-4.0.0-SNAPSHOT.jar"
#OPTS="-XX:+UseSerialGC -Xms1g -Xmx1g -XX:+AlwaysPreTouch -Dspring.context.exit=onRefresh -XX:+UnlockDiagnosticVMOptions -XX:+UnlockExperimentalVMOptions -jar ../spring-petclinic/target/spring-petclinic-2.1.0.BUILD-SNAPSHOT.jar"

C=3
NODES=0-$C

OPTS="-XX:-TieredCompilation $OPTS"
T_OPTS="$OPTS"
P_OPTS="$OPTS"

#P_OPTS="$OPTS -XX:+PreloadOnly"

SLEEP=10

T_REQ=100000
P_REQ=10000

T_CONC=10
P_CONC=1

URL=http://localhost:8080/vets.html

run_with() {
	J=$1
	L=$2

	rm -f *.aot *.aotconf

	rm -rf application
	$J/bin/java -Djarmode=tools $T_OPTS extract --destination application
        cd application

	$J/bin/java -XX:AOTMode=record -XX:AOTConfiguration=app.aotconf $T_OPTS &
        PID=$!
	sleep $SLEEP
	hey -c $T_CONC -n $T_REQ $URL
        kill $PID
        wait $PID

	$J/bin/java -XX:AOTMode=create -XX:AOTConfiguration=app.aotconf -XX:AOTCache=app.aot $T_OPTS
	#$J/bin/java -XX:AOTMode=create -XX:AOTConfiguration=app.aotconf -XX:AOTCache=app.aot -XX:+UnlockExperimentalVMOptions -XX:PerMethodSpecTrapLimit=0 -XX:PerMethodTrapLimit=0 $T_OPTS

#	taskset -c $NODES $J/bin/java -Xlog:deoptimization*=debug:file=deopt-$L.log:pid -agentpath:/home/shade/trunks/shipilev-async-profiler/build/lib/libasyncProfiler.so=start,event=cpu,file=profile.jfr,interval=50us,cstack=vm,jstackdepth=1 $P_OPTS &
#	taskset -c $NODES $J/bin/java -XX:AOTCache=app.aot -Xlog:deoptimization*=debug:file=deopt-$L.log -Xlog:jit+compilation=debug:file=jit-$L.log -agentpath:/home/shade/trunks/shipilev-async-profiler/build/lib/libasyncProfiler.so=start,event=cpu,file=profile.jfr,interval=50us,cstack=vm,jstackdepth=1 $P_OPTS &
#	taskset -c $NODES $J/bin/java -XX:AOTCache=app.aot   -Xlog:deoptimization*=debug:file=deopt.log:pid  $P_OPTS &
#	taskset -c $NODES $J/bin/java -XX:AOTCache=app.aot -XX:+PrintCompilation $P_OPTS &
	taskset -c $NODES $J/bin/java -XX:AOTCache=app.aot $P_OPTS &

        PID=$!
        sleep $SLEEP
	hey -o csv -c $P_CONC -n $P_REQ $URL > $OUT/$L.log
        kill $PID
        wait $PID

	jfr print --json --stack-depth 1 --events jdk.ExecutionSample profile.jfr | python ../../shipilev-leyden/parse-type.py | tail -n +2 > profile.data
	gnuplot ../../shipilev-leyden/plot.gnu
	mv plot.png ..
	cd ..
}

if [ "x" == "x${GRAPH_ONLY}" ]; then
	# -- JDK 17

#	taskset -c $NODES $J17/bin/java $P_OPTS &
#        PID=$!
#	sleep $SLEEP
#	hey -o csv -c $CONC -n $P_REQ $URL > $OUT/jdk17.log
#        kill $PID
#        wait $PID

	# -- JDK 21

#	taskset -c $NODES $J21/bin/java $P_OPTS &
#        PID=$!
#	sleep $SLEEP
#	hey -o csv -c $CONC -n $P_REQ $URL > $OUT/jdk21.log
#        kill $PID
#        wait $PID

	# -- JDK 25

#	taskset -c $NODES $J25/bin/java $P_OPTS &
#        PID=$!
#	sleep $SLEEP
#	hey -o csv -c $CONC -n $P_REQ $URL > $OUT/jdk25.log
#        kill $PID
#        wait $PID

	# -- JDK 25 AOT
	run_with $J25   jdk25-aot
	run_with $JLEA2 premain-ea2
	run_with $JL    premain-head
	run_with $JLB   premain-patched
fi

rm plot.gnu

cat <<EOF > plot.gnu
set terminal png size 3200, 800
set output "$OUT/plot-t${T_REQ}.png"
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

plot "$OUT/jdk25-aot.log" using (\$8+\$1):(\$1*1000) lw 5 with lines title 'JDK 25 (AOT)', \
     "$OUT/premain-ea2.log" using (\$8+\$1):(\$1*1000) lw 5 with lines title 'Leyden EA2', \
     "$OUT/premain-head.log" using (\$8+\$1):(\$1*1000) lw 5 with lines title 'Leyden nightly', \
     "$OUT/premain-patched.log" using (\$8+\$1):(\$1*1000) lw 5 with lines title 'Leyden/premain patched'

set xrange [0:10]
replot

set xrange [0:5]
replot

set xrange [0:2]
replot


EOF

gnuplot plot.gnu
