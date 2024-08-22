#/bin/bash

sudo cpupower frequency-set -g performance

# Config
HF_OPTS="-w 50 -r 100"

# Pull the binaries if not present
if [ ! -d jdk-17 ]; then
  curl https://builds.shipilev.net/openjdk-jdk21-dev/openjdk-jdk21-dev-linux-x86_64-server.tar.xz | tar xJf -
  mv jdk/ jdk-17/
fi

if [ ! -d jdk-21 ]; then
  curl https://builds.shipilev.net/openjdk-jdk21-dev/openjdk-jdk21-dev-linux-x86_64-server.tar.xz | tar xJf -
  mv jdk/ jdk-21/
fi

if [ ! -d jdk-23 ]; then
  curl https://builds.shipilev.net/openjdk-jdk23/openjdk-jdk23-linux-x86_64-server.tar.xz | tar xJf -
  mv jdk/ jdk-23/
fi

if [ ! -d jdk-mainline ]; then
  curl https://builds.shipilev.net/openjdk-jdk/openjdk-jdk-linux-x86_64-server.tar.xz | tar xJf -
  mv jdk/ jdk-mainline/
fi

if [ ! -d jdk-leyden ]; then
  curl https://builds.shipilev.net/openjdk-jdk-leyden-premain/openjdk-jdk-leyden-premain-linux-x86_64-server.tar.xz | tar xJf -
  mv jdk/ jdk-leyden/
fi

J17=jdk-17
J21=jdk-21
J23=jdk-23
JM=jdk-mainline
JL=jdk-leyden

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

	OPTS="$OPTS -cp hellostream.jar"
	rm -f *.aot *.aotconf *.class *.jar
	$J17/bin/javac HelloStream.java
	$J17/bin/jar cf hellostream.jar *.class

	# Go!
	lscpu | grep "Model name"
	echo

	echo "JDK 17"
	hyperfine $HF_OPTS "$J17/bin/java $OPTS HelloStream"

	echo "JDK 21"
	hyperfine $HF_OPTS "$J21/bin/java $OPTS HelloStream"

	echo "JDK 23"
	hyperfine $HF_OPTS "$J23/bin/java $OPTS HelloStream"

	echo "JDK MAINLINE"
	hyperfine $HF_OPTS "$JM/bin/java $OPTS HelloStream"

	echo "LEYDEN EMPTY"
	hyperfine $HF_OPTS "$JL/bin/java $OPTS HelloStream"

	# Build AOT
	rm -f *.aot *.aotconf
	$JL/bin/java -XX:AOTMode=record -XX:AOTConfiguration=app.aotconf $OPTS HelloStream
	$JL/bin/java -XX:AOTMode=create -XX:AOTConfiguration=app.aotconf $OPTS -XX:AOTCache=app.aot

	# Run AOT
	echo "LEYDEN AOT CACHE"
	hyperfine $HF_OPTS "$JL/bin/java -XX:AOTCache=app.aot $OPTS HelloStream"

	echo "LEYDEN CACHE DATA STORE"
 	rm -f *.cds
	hyperfine $HF_OPTS "$JL/bin/java -XX:CacheDataStore=app.cds $OPTS HelloStream"
}

run_with "-Xmx256m -Xms256m -XX:+UseSerialGC"					| tee results-serial.txt
run_with "-Xmx256m -Xms256m -XX:+UseParallelGC"					| tee results-parallel.txt
run_with "-Xmx256m -Xms256m -XX:+UseG1GC"					| tee results-g1.txt
run_with "-Xmx256m -Xms256m -XX:+UnlockExperimentalVMOptions -XX:+UseEpsilonGC" | tee results-epsilon.txt


