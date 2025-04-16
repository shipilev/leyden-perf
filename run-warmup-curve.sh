#/bin/bash

. setup.sh

JM=~/trunks/jdk/build/baseline-pp/
JP=~/trunks/jdk/build/linux-x86_64-server-release/images/jdk/

OUT=results/warmup-curve/

CORE_LIST="1 3"
CORE_LIST="1 3 7 15 31"

mkdir -p $OUT

rm -f *.class *.$OUT/jar
$J17/bin/javac JavacBenchApp.java
$J17/bin/jar cf JavacBenchApp.jar *.class

TI=500
RI=250

OPTS="-XX:+UseParallelGC -Xmn7g -Xms8g -Xmx8g -XX:+AlwaysPreTouch -cp JavacBenchApp.jar JavacBenchApp"

rm $OUT/*.ssv

for C in $CORE_LIST; do
NODES=0-$C

rm -f *.aot *.aotconf
taskset -c $NODES $JM/bin/java -XX:AOTCache=app.aot $OPTS $RI >> $OUT/mainline-$C.ssv

rm -f *.aot *.aotconf
$JM/bin/java -XX:AOTMode=record -XX:AOTConfiguration=app.aotconf $OPTS $TI
$JM/bin/java -XX:AOTMode=create -XX:AOTConfiguration=app.aotconf -XX:AOTCache=app.aot $OPTS $TI
taskset -c $NODES $JM/bin/java -XX:AOTCache=app.aot $OPTS $RI >> $OUT/mainline-aot-$C.ssv

rm -f *.aot *.aotconf
$JL/bin/java -XX:AOTMode=record -XX:AOTConfiguration=app.aotconf $OPTS $TI
$JL/bin/java -XX:AOTMode=create -XX:AOTConfiguration=app.aotconf -XX:AOTCache=app.aot $OPTS $TI
taskset -c $NODES $JL/bin/java -XX:AOTCache=app.aot $OPTS $RI >> $OUT/leyden-$C.ssv

rm -f *.aot *.aotconf
$JP/bin/java -XX:AOTMode=record -XX:AOTConfiguration=app.aotconf $OPTS $TI
$JP/bin/java -XX:AOTMode=create -XX:AOTConfiguration=app.aotconf -XX:AOTCache=app.aot $OPTS $TI
taskset -c $NODES $JP/bin/java -XX:AOTCache=app.aot $OPTS $RI >> $OUT/pp-$C.ssv

rm -f *.aot *.aotconf
$JP/bin/java -XX:AOTMode=record -XX:AOTConfiguration=app.aotconf $OPTS $TI
$JP/bin/java -XX:AOTMode=create -XX:AOTConfiguration=app.aotconf -XX:AOTCache=app.aot $OPTS $TI
taskset -c $NODES $JP/bin/java -XX:AOTCache=app.aot -XX:+UnlockDiagnosticVMOptions -XX:+UseNewCode $OPTS $RI >> $OUT/pp-new-$C.ssv

done

rm plot.gnu
cat <<EOF > plot.gnu
set terminal png size 2400, 2400
set output "$OUT/plot.png"

set multiplot layout 5,3

#set log y

set xlabel "iteration"

set key horiz
set key top left
set key box

#set ytics 100
#set xtics 200000
set grid xtics ytics mytics mxtics

EOF

for C in $CORE_LIST; do

cat <<EOF >> plot.gnu
set title "First N iterations; Cores: $(( $C + 1 ))"

set yrange [5000:50000]
set xrange [-2:50]
set ylabel "time per iteration, us"
plot "$OUT/mainline-$C.ssv" using 1:3 lw 5 with lines title 'Mainline', \
     "$OUT/mainline-aot-$C.ssv" using 1:3 lw 5 with lines title 'Mainline AOT', \
     "$OUT/leyden-$C.ssv" using 1:3 lw 5 with lines title 'Premain AOT', \
     "$OUT/pp-$C.ssv" using 1:3 lw 5 with lines title 'Pers Prof', \
     "$OUT/pp-new-$C.ssv" using 1:3 lw 5 with lines title 'Pers Prof (No Comp)'

set title "All iterations; Cores: $(( $C + 1 ))"
unset xrange
plot "$OUT/mainline-$C.ssv" using 1:3 lw 5 with lines title 'Mainline', \
     "$OUT/mainline-aot-$C.ssv" using 1:3 lw 5 with lines title 'Mainline AOT', \
     "$OUT/leyden-$C.ssv" using 1:3 lw 5 with lines title 'Premain AOT', \
     "$OUT/pp-$C.ssv" using 1:3 lw 5 with lines title 'Pers Prof', \
     "$OUT/pp-new-$C.ssv" using 1:3 lw 5 with lines title 'Pers Prof (No Comp)'


set title "All iterations, Integrated; Cores: $(( $C + 1 ))"
unset yrange
set ylabel "cumulative time, ms"
plot "$OUT/mainline-$C.ssv" using 1:2 lw 5 with lines title 'Mainline', \
     "$OUT/mainline-aot-$C.ssv" using 1:2 lw 5 with lines title 'Mainline AOT', \
     "$OUT/leyden-$C.ssv" using 1:2 lw 5 with lines title 'Premain AOT', \
     "$OUT/pp-$C.ssv" using 1:2 lw 5 with lines title 'Pers Prof', \
     "$OUT/pp-new-$C.ssv" using 1:2 lw 5 with lines title 'Pers Prof (No Comp)'
EOF
done

gnuplot plot.gnu
