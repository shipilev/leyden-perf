#/bin/bash

# CPU config
sudo cpupower frequency-set -g performance

J8=jdk-8
J11=jdk-11
J17=jdk-17
J21=jdk-21
J25=jdk-25
JM=jdk-mainline
JL=jdk-leyden
JL=/home/shade/trunks/shipilev-leyden/build/linux-x86_64-server-release/images/jdk/

# Pull the binaries if not present
if [ ! -d $J8 ]; then
  curl https://builds.shipilev.net/openjdk-jdk8-dev/openjdk-jdk8-dev-linux-x86_64-server.tar.xz | tar xJf -
  mv jdk/ $J8/
fi

if [ ! -d $J11 ]; then
  curl https://builds.shipilev.net/openjdk-jdk11-dev/openjdk-jdk11-dev-linux-x86_64-server.tar.xz | tar xJf -
  mv jdk/ $J11/
fi

if [ ! -d $J17 ]; then
  curl https://builds.shipilev.net/openjdk-jdk17-dev/openjdk-jdk17-dev-linux-x86_64-server.tar.xz | tar xJf -
  mv jdk/ $J17/
fi

if [ ! -d $J21 ]; then
  curl https://builds.shipilev.net/openjdk-jdk21-dev/openjdk-jdk21-dev-linux-x86_64-server.tar.xz | tar xJf -
  mv jdk/ $J21/
fi

if [ ! -d $J25 ]; then
  curl https://builds.shipilev.net/openjdk-jdk25/openjdk-jdk25-linux-x86_64-server.tar.xz | tar xJf -
  mv jdk/ $J25/
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
//        int iters = (args.length > 0) ? 1_000_000 : 1;
//        for (int i = 0; i < iters; i++) doOne();
//    }
//
//    public static void doOne() {
        List<String> words = Arrays.asList("hello", "fuzzy", "world");
        String greeting = words.stream()
            .filter(w -> !w.contains("z"))
            .collect(Collectors.joining(", "));
        System.out.println(greeting + "!");  // hello, world
    }
}
EOF

cat > Hello.java <<EOF
public class Hello {
    public static void main(String ... args) {
        System.out.println("Hello World!");
    }
}
EOF


rm -f *.class *.jar
$J8/bin/javac HelloStream.java
$J8/bin/javac Hello.java
$J8/bin/jar cf hello.jar *.class

rm -f *.class
$J17/bin/javac JavacBenchApp.java
$J17/bin/jar cf JavacBenchApp.jar *.class
