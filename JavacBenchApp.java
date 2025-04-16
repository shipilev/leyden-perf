/*
 * Copyright (c) 2023, 2024, Oracle and/or its affiliates. All rights reserved.
 * DO NOT ALTER OR REMOVE COPYRIGHT NOTICES OR THIS FILE HEADER.
 *
 * This code is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License version 2 only, as
 * published by the Free Software Foundation.
 *
 * This code is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
 * version 2 for more details (a copy is included in the LICENSE file that
 * accompanied this code).
 *
 * You should have received a copy of the GNU General Public License version
 * 2 along with this work; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA.
 *
 * Please contact Oracle, 500 Oracle Parkway, Redwood Shores, CA 94065 USA
 * or visit www.oracle.com if you need additional information or have any
 * questions.
 *
 */

import java.lang.invoke.MethodHandles;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.net.URI;
import java.util.Arrays;
import java.util.ArrayList;
import java.util.Collection;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Random;
import java.util.concurrent.Callable;
import javax.tools.Diagnostic;
import javax.tools.DiagnosticCollector;
import javax.tools.FileObject;
import javax.tools.ForwardingJavaFileManager;
import javax.tools.JavaCompiler;
import javax.tools.JavaFileManager;
import javax.tools.JavaFileObject;
import javax.tools.SimpleJavaFileObject;
import javax.tools.ToolProvider;

/**
 * This program tries to compile a large number of classes that exercise a fair amount of
 * features in javac.
 */
public class JavacBenchApp {
    static class ClassFile extends SimpleJavaFileObject {
        private final ByteArrayOutputStream baos = new ByteArrayOutputStream();
        protected ClassFile(String name) {
            super(URI.create("memo:///" + name.replace('.', '/') + Kind.CLASS.extension), Kind.CLASS);
        }
        @Override
        public ByteArrayOutputStream openOutputStream() {
            return this.baos;
        }
        byte[] toByteArray() {
            return baos.toByteArray();
        }
    }

    static class FileManager extends ForwardingJavaFileManager<JavaFileManager> {
        private Map<String, ClassFile> classesMap = new HashMap<String, ClassFile>();
        protected FileManager(JavaFileManager fileManager) {
            super(fileManager);
        }
        @Override
        public ClassFile getJavaFileForOutput(Location location, String name, JavaFileObject.Kind kind, FileObject source) {
            ClassFile classFile = new ClassFile(name);
            classesMap.put(name, classFile);
            return classFile;
        }
        public Map<String, byte[]> getCompiledClasses() {
            Map<String, byte[]> result = new HashMap<>();
            for (Map.Entry<String, ClassFile> entry : classesMap.entrySet()) {
                result.put(entry.getKey(), entry.getValue().toByteArray());
            }
            return result;
        }
    }

    static class SourceFile extends SimpleJavaFileObject {
        private CharSequence sourceCode;
        public SourceFile(String name, CharSequence sourceCode) {
            super(URI.create("memo:///" + name.replace('.', '/') + Kind.SOURCE.extension), Kind.SOURCE);
            this.sourceCode = sourceCode;
        }
        @Override
        public CharSequence getCharContent(boolean ignore) {
            return this.sourceCode;
        }
    }

    public byte[] compile(SourceFile sf) {
        JavaCompiler compiler = ToolProvider.getSystemJavaCompiler();
        DiagnosticCollector<JavaFileObject> ds = new DiagnosticCollector<>();
        Collection<SourceFile> sourceFiles = Collections.singletonList(sf);

        try (FileManager fileManager = new FileManager(compiler.getStandardFileManager(ds, null, null))) {
            JavaCompiler.CompilationTask task = compiler.getTask(null, fileManager, null, null, null, sourceFiles);
            if (task.call()) {
                return fileManager.getCompiledClasses().values().iterator().next();
            } else {
                for (Diagnostic<? extends JavaFileObject> d : ds.getDiagnostics()) {
                    System.out.format("Line: %d, %s in %s", d.getLineNumber(), d.getMessage(null), d.getSource().getName());
                }
                throw new InternalError("compilation failure");
            }
        } catch (IOException e) {
            throw new InternalError(e);
        }
    }


    static final String imports = """
        import java.lang.*;
        import java.util.*;
        """;

    static final String testClassBody = """
        // Some comments
        static long x;
        static final long y;
        static {
            y = System.currentTimeMillis();
        }
        /* More comments */
        @Deprecated
        String func() { return "String " + this + y; }
        public static void main(String args[]) {
            try {
                x = Long.parseLong(args[0]);
            } catch (Throwable t) {
                t.printStackTrace();
            }
            doit(() -> {
                System.out.println("Hello Lambda");
                Thread.dumpStack();
            });
        }
        static List<String> list = List.of("1", "2");
        class InnerClass1 {
            static final long yy = y;
        }
        static void doit(Runnable r) {
            for (var x : list) {
                r.run();
            }
        }
        static String patternMatch(String arg, Object o) {
            if (o instanceof String s) {
                return "1234";
            }
            final String b = "B";
            return switch (arg) {
                case "A" -> "a";
                case b   -> "b";
                default  -> "c";
            };
        }
        public sealed class SealedInnerClass {}
        public final class Foo extends SealedInnerClass {}
        enum Expression {
            ADDITION,
            SUBTRACTION,
            MULTIPLICATION,
            DIVISION
        }
        public record Point(int x, int y) {
            public Point(int x) {
                this(x, 0);
            }
        }
        """;

    String sanitySource = """
        public class Sanity implements java.util.concurrent.Callable<String> {
            public String call() {
                return "this is a test";
            }
        }
        """;

    Random r =  new Random();

    List<SourceFile> sources;

    void setup(int count) {
        sources = new ArrayList<>(count);
        int base = r.nextInt(1024*1024) ;
        for (int i = 0; i < count; i++) {
            int idx = base + i;
            String source = imports + "public class Test" + idx + " {" + testClassBody + "}";
            sources.add(new SourceFile("Test" + idx, source));
        }
    }

    public static void main(String args[]) throws Throwable {
        JavacBenchApp bench = new JavacBenchApp();

        if (args.length > 0) {
            int count = Integer.parseInt(args[0]);
            if (count >= 0) {
                bench.setup(count);
        	long started = System.nanoTime();
		for (int i = 0; i < bench.sources.size(); i++) {
        		long startedIter = System.nanoTime();
			SourceFile sf = bench.sources.get(i);
                	byte[] compile = bench.compile(sf);
        		long finishedIter = System.nanoTime();
			System.out.println(i + " " + (finishedIter - started)/1000/1000 + " " + " " + (finishedIter - startedIter) / 1000 + " " + Arrays.hashCode(compile));
		}
            }
        }
    }
}

