#!/bin/bash

# CPU config
sudo cpupower frequency-set -g performance

# Config
HF_OPTS="-w 10 -r 10 -P mx 128 32768 -D 128 -s basic"

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

for GC in Epsilon Serial Parallel G1 Shenandoah; do
  hyperfine $HF_OPTS --export-csv default-${GC}.csv    "$JM/bin/java -XX:+UnlockExperimentalVMOptions -XX:+Use${GC}GC -Xmx{mx}m Hello"
  hyperfine $HF_OPTS --export-csv small-init-${GC}.csv "$JM/bin/java -XX:+UnlockExperimentalVMOptions -XX:+Use${GC}GC -XX:InitialRAMPercentage=0.2 -Xmx{mx}m Hello"
done

for GC in Serial Parallel G1 Epsilon Shenandoah; do
  cat default-${GC}.csv | tail -n +2 | cut -d',' -f 2,3,9 | tr ',' ' ' > default-${GC}.dat 
  cat small-init-${GC}.csv | tail -n +2 | cut -d',' -f 2,3,9 | tr ',' ' ' > small-init-${GC}.dat 
done

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