#/bin/bash

# CPU config
NODES=0-16
sudo cpupower frequency-set -g performance
#sudo cpupower frequency-set -u 4200000

# Config
HF_OPTS="-w 30 -r 100"
#HF_OPTS="-w 1 -r 5"

J17=jdk-17
J21=jdk-21
J23=jdk-23
JM=jdk-mainline
JL=jdk-leyden

# Pull the binaries if not present
if [ ! -d $J17 ]; then
  curl https://builds.shipilev.net/openjdk-jdk17-dev/openjdk-jdk17-dev-linux-x86_64-server.tar.xz | tar xJf -
  mv jdk/ $J17/
fi

if [ ! -d $J21 ]; then
  curl https://builds.shipilev.net/openjdk-jdk21-dev/openjdk-jdk21-dev-linux-x86_64-server.tar.xz | tar xJf -
  mv jdk/ $J21/
fi

if [ ! -d $J23 ]; then
  curl https://builds.shipilev.net/openjdk-jdk23/openjdk-jdk23-linux-x86_64-server.tar.xz | tar xJf -
  mv jdk/ $J23/
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

	rm -f *.aot *.aotconf *.class *.jar
	$J17/bin/javac HelloStream.java
	$J17/bin/jar cf hellostream.jar *.class
	OPTS="$OPTS -cp hellostream.jar"
	APP="HelloStream"

#	APP="HelloStream.java"

	# Go!
	lscpu | grep "Model name"
	echo

	echo "JDK 17"
	taskset -c $NODES hyperfine $HF_OPTS "$J17/bin/java $OPTS $APP"

	echo "JDK 21"
	taskset -c $NODES hyperfine $HF_OPTS "$J21/bin/java $OPTS $APP"

	echo "JDK 23"
	taskset -c $NODES hyperfine $HF_OPTS "$J23/bin/java $OPTS $APP"

	echo "JDK MAINLINE, OUT OF BOX"
	taskset -c $NODES hyperfine $HF_OPTS "$JM/bin/java $OPTS $APP"

	# Build AOT
        echo "Generating AOT..."
	rm -f *.aot *.aotconf
	time $JM/bin/java -XX:AOTMode=record -XX:AOTConfiguration=app.aotconf $OPTS $APP
	time $JM/bin/java -XX:AOTMode=create -XX:AOTConfiguration=app.aotconf $OPTS -XX:AOTCache=app.aot
        echo

	echo "JDK MAINLINE, AOT CACHE"
	taskset -c $NODES hyperfine $HF_OPTS "$JM/bin/java -XX:AOTCache=app.aot $OPTS $APP"

	echo "LEYDEN, OUT OF BOX"
	taskset -c $NODES hyperfine $HF_OPTS "$JL/bin/java $OPTS $APP"

	# Build AOT
        echo "Generating AOT..."
	rm -f *.aot *.aotconf
	time $JL/bin/java -XX:AOTMode=record -XX:AOTConfiguration=app.aotconf $OPTS $APP
	time $JL/bin/java -XX:AOTMode=create -XX:AOTConfiguration=app.aotconf $OPTS -XX:AOTCache=app.aot
        echo

	# Run AOT
	echo "LEYDEN, AOT CACHE"
	taskset -c $NODES hyperfine $HF_OPTS "$JL/bin/java -XX:AOTCache=app.aot $OPTS $APP"

	echo "LEYDEN, CACHE DATA STORE"
 	rm -f app.cds*
	taskset -c $NODES hyperfine $HF_OPTS "$JL/bin/java -XX:CacheDataStore=app.cds $OPTS $APP"
}

HEAP="-Xms64m -Xmx64m"

run_with "$HEAP -XX:+UseSerialGC"					| tee results-serial.txt
run_with "$HEAP -XX:+UseParallelGC"					| tee results-parallel.txt
run_with "$HEAP -XX:+UseG1GC"		 				| tee results-g1.txt
run_with "$HEAP -XX:+UseShenandoahGC"		 			| tee results-shenandoah.txt
run_with "$HEAP -XX:+UnlockExperimentalVMOptions -XX:+UseEpsilonGC"	| tee results-epsilon.txt

cd ..
