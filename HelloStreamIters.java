import java.util.*;
import java.util.stream.*;

public class HelloStreamIters {
    static volatile String sink;

    public static long invoke() {
        long time1 = System.nanoTime();
       	var words = List.of("hello", "fuzzy", "world");
        sink = words.stream()
            .filter(w -> !w.contains("z"))
            .collect(Collectors.joining(", "));
        long time2 = System.nanoTime();
	return time2 - time1;
    }

    public static void main(String ... args) {
	int len = 10;
	if (args.length >= 1) {
		len = Integer.parseInt(args[0]);
	}
	long[] time = new long[len];
	for (int c = 0; c < len; c++) {
		time[c] = invoke();
	}
	long sum = 0;
	for (long t : time) {
		sum += t;
		System.out.println(sum + " " + t);
	}
    }
}
