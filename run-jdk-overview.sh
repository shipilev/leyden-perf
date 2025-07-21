#/bin/bash

. setup.sh

# CPU config
NODES=0-7

# Config
HF_OPTS="-w 30 -r 100"
#HF_OPTS="-w 100 -r 500"

OUT=results/jdk-overview/
mkdir -p $OUT

run_with() {
	OPTS=$1

	# Work around JDK-8348278: Trim InitialRAMPercentage to improve startup in default modes
	#OPTS="$OPTS -Xms64m -Xmx512m"
	OPTS="$OPTS -Xmx256m"

	LEYDEN_OPTS="$OPTS"

	rm -f *.aot *.aotconf *.class *.jar
	$J11/bin/javac HelloStream.java
	$J11/bin/jar cf hellostream.jar *.class
	OPTS="$OPTS -cp hellostream.jar"
	APP="HelloStream"

	# Go!
#	lscpu | grep "Model name"
#	echo

	echo "JDK 8"
	taskset -c $NODES hyperfine $HF_OPTS "$J8/bin/java $OPTS $APP"

	echo "JDK 11"
	taskset -c $NODES hyperfine $HF_OPTS "$J11/bin/java $OPTS $APP"

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

	echo "JDK MAINLINE (JDK 25+)"
	taskset -c $NODES hyperfine $HF_OPTS "$JM/bin/java $OPTS $APP"

	# Build AOT
        echo "Generating AOT..."
	rm -f *.aot *.aotconf
	$JM/bin/java -XX:AOTMode=record -XX:AOTConfiguration=app.aotconf $OPTS $APP
	$JM/bin/java -XX:AOTMode=create -XX:AOTConfiguration=app.aotconf $OPTS -XX:AOTCache=app.aot
        echo

	echo "JDK MAINLINE (JDK 25+), AOT CACHE ENABLED"
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

run_with "-XX:+UseSerialGC"					| tee $OUT/results-serial.txt
run_with "-XX:+UseParallelGC"					| tee $OUT/results-parallel.txt
run_with "-XX:+UseG1GC"		 				| tee $OUT/results-g1.txt
run_with "-XX:+UseShenandoahGC"		 			| tee $OUT/results-shenandoah.txt
run_with "-XX:+UnlockExperimentalVMOptions -XX:+UseEpsilonGC"	| tee $OUT/results-epsilon.txt

cd ..
