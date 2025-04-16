#/bin/bash

. setup.sh

JM=~/trunks/jdk/build/baseline-pp/
JP=~/trunks/jdk/build/linux-x86_64-server-release/images/jdk/

OUT=results/warmup-curve/

# CPU config
NODES=0-7

mkdir -p $OUT

rm -f *.class *.$OUT/jar
$J17/bin/javac JavacBenchApp.java
$J17/bin/jar cf JavacBenchApp.jar *.class

TI=500
RI=250

OPTS="-XX:+UseParallelGC -Xmn7g -Xms8g -Xmx8g -XX:+AlwaysPreTouch -cp JavacBenchApp.jar JavacBenchApp"

rm $OUT/*.ssv

rm -f *.aot *.aotconf
taskset -c $NODES $JM/bin/java -XX:AOTCache=app.aot $OPTS $RI >> $OUT/mainline.ssv

rm -f *.aot *.aotconf
$JM/bin/java -XX:AOTMode=record -XX:AOTConfiguration=app.aotconf $OPTS $TI
$JM/bin/java -XX:AOTMode=create -XX:AOTConfiguration=app.aotconf -XX:AOTCache=app.aot $OPTS $TI
taskset -c $NODES $JM/bin/java -XX:AOTCache=app.aot $OPTS $RI >> $OUT/mainline-aot.ssv

rm -f *.aot *.aotconf
$JL/bin/java -XX:AOTMode=record -XX:AOTConfiguration=app.aotconf $OPTS $TI
$JL/bin/java -XX:AOTMode=create -XX:AOTConfiguration=app.aotconf -XX:AOTCache=app.aot $OPTS $TI
taskset -c $NODES $JL/bin/java -XX:AOTCache=app.aot $OPTS $RI >> $OUT/leyden.ssv

rm -f *.aot *.aotconf
$JP/bin/java -XX:AOTMode=record -XX:AOTConfiguration=app.aotconf $OPTS $TI
$JP/bin/java -XX:AOTMode=create -XX:AOTConfiguration=app.aotconf -XX:AOTCache=app.aot $OPTS $TI
taskset -c $NODES $JP/bin/java -XX:AOTCache=app.aot $OPTS $RI >> $OUT/pp.ssv

rm -f *.aot *.aotconf
$JP/bin/java -XX:AOTMode=record -XX:AOTConfiguration=app.aotconf $OPTS $TI
$JP/bin/java -XX:AOTMode=create -XX:AOTConfiguration=app.aotconf -XX:AOTCache=app.aot $OPTS $TI
taskset -c $NODES $JP/bin/java -XX:AOTCache=app.aot -XX:+UnlockDiagnosticVMOptions -XX:+UseNewCode $OPTS $RI >> $OUT/pp-new.ssv

rm plot.gnu
cat <<EOF > plot.gnu
set terminal png size 2400, 800
set output "$OUT/plot.png"

set multiplot layout 1,3

#set xrange [-2:*]
#set yrange [5000:100000]

#set log y

set xlabel "iteration"

set key horiz
set key top left
set key box 

#set ytics 100
#set xtics 200000
set grid xtics ytics mytics mxtics

set title ""

set yrange [5000:100000]
set xrange [-2:50]
set ylabel "time per iteration, us"
plot "$OUT/mainline.ssv" using 1:3 lw 5 with lines title 'Mainline', \
     "$OUT/mainline-aot.ssv" using 1:3 lw 5 with lines title 'Mainline AOT', \
     "$OUT/leyden.ssv" using 1:3 lw 5 with lines title 'Leyden AOT', \
     "$OUT/pp.ssv" using 1:3 lw 5 with lines title 'Persistent Profiles', \
     "$OUT/pp-new.ssv" using 1:3 lw 5 with lines title 'Persistent Profiles (New)'

unset xrange
plot "$OUT/mainline.ssv" using 1:3 lw 5 with lines title 'Mainline', \
     "$OUT/mainline-aot.ssv" using 1:3 lw 5 with lines title 'Mainline AOT', \
     "$OUT/leyden.ssv" using 1:3 lw 5 with lines title 'Leyden AOT', \
     "$OUT/pp.ssv" using 1:3 lw 5 with lines title 'Persistent Profiles', \
     "$OUT/pp-new.ssv" using 1:3 lw 5 with lines title 'Persistent Profiles (New)'


unset yrange
set ylabel "cumulative time, ms"
plot "$OUT/mainline.ssv" using 1:2 lw 5 with lines title 'Mainline', \
     "$OUT/mainline-aot.ssv" using 1:2 lw 5 with lines title 'Mainline AOT', \
     "$OUT/leyden.ssv" using 1:2 lw 5 with lines title 'Leyden AOT', \
     "$OUT/pp.ssv" using 1:2 lw 5 with lines title 'Persistent Profiles', \
     "$OUT/pp-new.ssv" using 1:2 lw 5 with lines title 'Persistent Profiles (New)'
EOF

gnuplot plot.gnu
