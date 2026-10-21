package com.ironcorelabs.vespa.cloakedai;

import java.io.IOException;
import java.io.InputStream;
import java.io.UncheckedIOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;

/**
 * Copies the libironcore_alloy.so packaged in the ironcore-alloy-java jar to disk and points the
 * alloy loader at it. Must run before the first use of an alloy class in this bundle.
 */
final class AlloyNativeLibrary {

    private static final String OVERRIDE_PROPERTY = "uniffi.component.ironcore_alloy.libraryOverride";

    private static boolean installed = false;

    private AlloyNativeLibrary() {}

    // A fresh file per bundle class loader: the JVM binds a native library path to one class loader.
    static synchronized void install() {
        if (installed) return;
        String resource = resourceDirectory() + "/libironcore_alloy.so";
        try (InputStream library = AlloyNativeLibrary.class.getClassLoader().getResourceAsStream(resource)) {
            if (library == null)
                throw new IllegalStateException(resource + " is not on the bundle class path");
            Path file = Files.createTempFile("libironcore_alloy", ".so");
            file.toFile().deleteOnExit();
            Files.copy(library, file, StandardCopyOption.REPLACE_EXISTING);
            System.setProperty(OVERRIDE_PROPERTY, file.toAbsolutePath().toString());
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
        installed = true;
    }

    private static String resourceDirectory() {
        String os = System.getProperty("os.name");
        String arch = System.getProperty("os.arch");
        if (!os.equals("Linux"))
            throw new IllegalStateException("Unsupported OS for ironcore-alloy: " + os);
        return switch (arch) {
            case "amd64", "x86_64" -> "linux-x86-64";
            case "aarch64" -> "linux-arm";
            default -> throw new IllegalStateException("Unsupported architecture for ironcore-alloy: " + arch);
        };
    }

}
