#/bin/bash

# CPU config
sudo cpupower frequency-set -g performance

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

