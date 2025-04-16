#/bin/bash

# CPU config
NODES=0-15
#NODES=0-31
sudo cpupower frequency-set -g performance

# Config
HF_OPTS="-w 30 -r 100"
#HF_OPTS="-w 1 -r 5"

J17=jdk-17
J21=jdk-21
J24=jdk-24
JM=jdk-mainline
JL=jdk-leyden
#JL=/home/shade/trunks/shipilev-leyden/build/linux-x86_64-server-release/images/jdk/

# Pull the binaries if not present
if [ ! -d $J17 ]; then
  curl https://builds.shipilev.net/openjdk-jdk17-dev/openjdk-jdk17-dev-linux-x86_64-server.tar.xz | tar xJf -
  mv jdk/ $J17/
fi

if [ ! -d $J21 ]; then
  curl https://builds.shipilev.net/openjdk-jdk21-dev/openjdk-jdk21-dev-linux-x86_64-server.tar.xz | tar xJf -
  mv jdk/ $J21/
fi

if [ ! -d $J24 ]; then
  curl https://builds.shipilev.net/openjdk-jdk24/openjdk-jdk24-linux-x86_64-server.tar.xz | tar xJf -
  mv jdk/ $J24/
fi

if [ ! -d $JM ]; then
  curl https://builds.shipilev.net/openjdk-jdk/openjdk-jdk-linux-x86_64-server.tar.xz | tar xJf -
  mv jdk/ $JM/
fi

if [ ! -d $JL ]; then
  curl https://builds.shipilev.net/openjdk-jdk-leyden-premain/openjdk-jdk-leyden-premain-linux-x86_64-server.tar.xz | tar xJf -
  mv jdk/ $JL/
fi

# Prepare JAR
cat > HelloStream.java <<EOF
import java.util.*;
import java.util.stream.*;

public class HelloStream {
    public static void main(String ... args) {
        var words = List.of("hello", "fuzzy", "world");
        var greeting = words.stream()
            .filter(w -> !w.contains("z"))
            .collect(Collectors.joining(", "));
        System.out.println(greeting);  // hello, world
    }
}
EOF

run_with() {
	OPTS=$1

	# Work around JDK-8348278: Trim InitialRAMPercentage to improve startup in default modes
	OPTS="$OPTS -Xmx64m -Xms64m"

	LEYDEN_OPTS="$OPTS"

	rm -f *.aot *.aotconf *.class *.jar
	$J17/bin/javac HelloStream.java
	$J17/bin/jar cf hellostream.jar *.class
	OPTS="$OPTS -cp hellostream.jar"
	APP="HelloStream"

	# Go!
	lscpu | grep "Model name"
	echo

	echo "JDK 17"
	taskset -c $NODES hyperfine $HF_OPTS "$J17/bin/java $OPTS $APP"

	echo "JDK 21"
	taskset -c $NODES hyperfine $HF_OPTS "$J21/bin/java $OPTS $APP"

	echo "JDK 24"
	taskset -c $NODES hyperfine $HF_OPTS "$J24/bin/java $OPTS $APP"

	# Build AOT
        echo "Generating AOT..."
	rm -f *.aot *.aotconf
	$J24/bin/java -XX:AOTMode=record -XX:AOTConfiguration=app.aotconf $OPTS $APP
	$J24/bin/java -XX:AOTMode=create -XX:AOTConfiguration=app.aotconf $OPTS -XX:AOTCache=app.aot
        echo

	echo "JDK 24, AOT CACHE ENABLED"
	taskset -c $NODES hyperfine $HF_OPTS "$J24/bin/java -XX:AOTCache=app.aot $OPTS $APP"

	echo "JDK MAINLINE"
	taskset -c $NODES hyperfine $HF_OPTS "$JM/bin/java $OPTS $APP"

	# Build AOT
        echo "Generating AOT..."
	rm -f *.aot *.aotconf
	$JM/bin/java -XX:AOTMode=record -XX:AOTConfiguration=app.aotconf $OPTS $APP
	$JM/bin/java -XX:AOTMode=create -XX:AOTConfiguration=app.aotconf $OPTS -XX:AOTCache=app.aot
        echo

	echo "JDK MAINLINE, AOT CACHE ENABLED"
	taskset -c $NODES hyperfine $HF_OPTS "$JM/bin/java -XX:AOTCache=app.aot $OPTS $APP"

	echo "LEYDEN"
	taskset -c $NODES hyperfine $HF_OPTS "$JL/bin/java $OPTS $APP"

	# Build AOT
        echo "Generating AOT..."
	rm -f *.aot *.aotconf
	$JL/bin/java -XX:AOTMode=record -XX:AOTConfiguration=app.aotconf $LEYDEN_OPTS $APP
	$JL/bin/java -XX:AOTMode=create -XX:AOTConfiguration=app.aotconf $LEYDEN_OPTS -XX:AOTCache=app.aot
        echo

	echo "LEYDEN, AOT CACHE ENABLED"
	taskset -c $NODES hyperfine $HF_OPTS "$JL/bin/java -XX:AOTCache=app.aot $LEYDEN_OPTS $APP"
}

run_with "-XX:+UseSerialGC"					| tee results-serial.txt
run_with "-XX:+UseParallelGC"					| tee results-parallel.txt
run_with "-XX:+UseG1GC"		 				| tee results-g1.txt
run_with "-XX:+UseShenandoahGC"		 			| tee results-shenandoah.txt
run_with "-XX:+UnlockExperimentalVMOptions -XX:+UseEpsilonGC"	| tee results-epsilon.txt

cd ..
