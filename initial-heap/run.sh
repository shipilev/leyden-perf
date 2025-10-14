#!/bin/bash

# CPU config
sudo cpupower frequency-set -g performance

# Config
HF_OPTS="-w 10 -r 10 -P mx 128 32768 -D 128 -s basic"
HF_OPTS="-w 10 -r 10 -P mx 128 32768 -D 256"
#HF_OPTS="-w 10 -r 10 -P mx 128 1024 -D 128"

JM=jdk-mainline

if [ ! -d $JM ]; then
  curl https://builds.shipilev.net/openjdk-jdk/openjdk-jdk-linux-x86_64-server.tar.xz | tar xJf -
  mv jdk/ $JM/
fi

# Prepare code
cat > Hello.java <<EOF
public class Hello {
    public static void main(String ... args) {
        System.out.println("Hello, world!");
    }
}
EOF
rm -f *.aot *.aotconf *.class *.jar
$JM/bin/javac Hello.java

lscpu | grep "Model name"

#for GC in Epsilon Serial Parallel G1 Shenandoah; do
#for MX in 1 2 4 8 16 31; do
#  hyperfine $HF_OPTS --export-csv Xms-${MX}-${GC}.csv  "$JM/bin/java -XX:+UnlockExperimentalVMOptions -XX:+Use${GC}GC -Xms{mx}m -Xmx${MX}g Hello"
#done
#done

#  hyperfine $HF_OPTS --export-csv default-${GC}.csv    "$JM/bin/java -XX:+UnlockExperimentalVMOptions -XX:+Use${GC}GC -Xmx{mx}m Hello"
#  hyperfine $HF_OPTS --export-csv small-init-${GC}.csv "$JM/bin/java -XX:+UnlockExperimentalVMOptions -XX:+Use${GC}GC -XX:InitialRAMPercentage=0.2 -Xmx{mx}m Hello"

for GC in Serial Parallel G1 Epsilon Shenandoah; do
for MX in 1 2 4 8 16 31; do
  cat Xms-${MX}-${GC}.csv | tail -n +2 | cut -d',' -f 2,3,9 | tr ',' ' ' > Xms-${MX}-${GC}.dat
done
  cat default-${GC}.csv | tail -n +2 | cut -d',' -f 2,3,9 | tr ',' ' ' > default-${GC}.dat
  cat small-init-${GC}.csv | tail -n +2 | cut -d',' -f 2,3,9 | tr ',' ' ' > small-init-${GC}.dat
done

cat > plot.gnu <<EOF
set terminal png size 2000, 600
set output "plot-xms.png"

set multiplot layout 1,5

#set log x
#set log y

#set xrange [0:4096]
set yrange [15:70]

set ylabel "HelloWorld time, msec"
set xlabel "Xms, MB"

set key horiz
#set key top right
set key box
set key outside bottom

#set ytics 100
set xtics 8192
set grid xtics ytics

EOF

for GC in Epsilon Serial Parallel G1 Shenandoah; do
cat >> plot.gnu <<EOF
set title "$GC"
plot 'Xms-1-$GC.dat' using 3:(\$1*1000):(\$1-\$2)*1000:(\$1+\$2)*1000 with errorbars title 'Xmx1g',   \
     'Xms-2-$GC.dat' using 3:(\$1*1000):(\$1-\$2)*1000:(\$1+\$2)*1000 with errorbars title 'Xmx2g',   \
     'Xms-4-$GC.dat' using 3:(\$1*1000):(\$1-\$2)*1000:(\$1+\$2)*1000 with errorbars title 'Xmx4g',   \
     'Xms-8-$GC.dat' using 3:(\$1*1000):(\$1-\$2)*1000:(\$1+\$2)*1000 with errorbars title 'Xmx8g',   \
     'Xms-16-$GC.dat' using 3:(\$1*1000):(\$1-\$2)*1000:(\$1+\$2)*1000 with errorbars title 'Xmx16g', \
     'Xms-31-$GC.dat' using 3:(\$1*1000):(\$1-\$2)*1000:(\$1+\$2)*1000 with errorbars title 'Xmx31g'
EOF
done


gnuplot plot.gnu

cat > plot.gnu <<EOF
set terminal png size 800, 1600
set output "plot.png"

set multiplot layout 5,1

#set xrange [0:2000000]
set yrange [0:50]

set ylabel "HelloWorld time, msec"
set xlabel "Xmx, MB"

set key horiz
set key top right
set key box 

#set ytics 100
set xtics 4096
set grid xtics ytics

set title "Epsilon"
plot 'default-Epsilon.dat' using 3:(\$1*1000):(\$1-\$2)*1000:(\$1+\$2)*1000 with errorbars title "default", \
     'small-init-Epsilon.dat' using 3:(\$1*1000):(\$1-\$2)*1000:(\$1+\$2)*1000 with errorbars title "IRAMP=0.2"

set title "Serial"
plot 'default-Serial.dat' using 3:(\$1*1000):(\$1-\$2)*1000:(\$1+\$2)*1000 with errorbars title "default", \
     'small-init-Serial.dat' using 3:(\$1*1000):(\$1-\$2)*1000:(\$1+\$2)*1000 with errorbars title "IRAMP=0.2"

set title "Parallel"
plot 'default-Parallel.dat' using 3:(\$1*1000):(\$1-\$2)*1000:(\$1+\$2)*1000 with errorbars title "default", \
     'small-init-Parallel.dat' using 3:(\$1*1000):(\$1-\$2)*1000:(\$1+\$2)*1000 with errorbars title "IRAMP=0.2"

set title "G1"
plot 'default-G1.dat' using 3:(\$1*1000):(\$1-\$2)*1000:(\$1+\$2)*1000 with errorbars title "default", \
     'small-init-G1.dat' using 3:(\$1*1000):(\$1-\$2)*1000:(\$1+\$2)*1000 with errorbars title "IRAMP=0.2"

set title "Shenandoah"
plot 'default-Shenandoah.dat' using 3:(\$1*1000):(\$1-\$2)*1000:(\$1+\$2)*1000 with errorbars title "default", \
     'small-init-Shenandoah.dat' using 3:(\$1*1000):(\$1-\$2)*1000:(\$1+\$2)*1000 with errorbars title "IRAMP=0.2"
EOF

gnuplot plot.gnu
