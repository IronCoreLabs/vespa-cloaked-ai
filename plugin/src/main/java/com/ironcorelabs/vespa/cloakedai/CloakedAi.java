package com.ironcorelabs.vespa.cloakedai;

import com.ironcorelabs.ironcore_alloy_java.AlloyException;
import com.ironcorelabs.ironcore_alloy_java.AlloyMetadata;
import com.ironcorelabs.ironcore_alloy_java.DerivationPath;
import com.ironcorelabs.ironcore_alloy_java.EncryptedVector;
import com.ironcorelabs.ironcore_alloy_java.PlaintextVector;
import com.ironcorelabs.ironcore_alloy_java.PlaintextVectors;
import com.ironcorelabs.ironcore_alloy_java.RotatableSecret;
import com.ironcorelabs.ironcore_alloy_java.Secret;
import com.ironcorelabs.ironcore_alloy_java.SecretPath;
import com.ironcorelabs.ironcore_alloy_java.Standalone;
import com.ironcorelabs.ironcore_alloy_java.StandaloneConfiguration;
import com.ironcorelabs.ironcore_alloy_java.StandaloneSecret;
import com.ironcorelabs.ironcore_alloy_java.StandaloneVectorClient;
import com.ironcorelabs.ironcore_alloy_java.StandardSecrets;
import com.ironcorelabs.ironcore_alloy_java.TenantId;
import com.ironcorelabs.ironcore_alloy_java.VectorId;
import com.ironcorelabs.ironcore_alloy_java.VectorSecret;
import com.yahoo.component.AbstractComponent;
import com.yahoo.component.annotation.Inject;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Base64;
import java.util.List;
import java.util.Map;

/** Cloaked AI vector encryption with a single standalone secret, shared by the document processor and searcher. */
public class CloakedAi extends AbstractComponent {

    private static final SecretPath SECRET_PATH = new SecretPath("");
    private static final DerivationPath DERIVATION_PATH = new DerivationPath("");
    private static final VectorId QUERY_ID = new VectorId("query");

    private final CloakedAiConfig config;
    private final Standalone alloy;
    private final StandaloneVectorClient vectors;
    private final AlloyMetadata metadata;

    @Inject
    public CloakedAi(CloakedAiConfig config) {
        AlloyNativeLibrary.install();
        this.config = config;
        try {
            var secret = new StandaloneSecret(config.secretId(), new Secret(readSecret(Path.of(config.secretFile()))));
            var vectorSecret = new VectorSecret((float) config.approximationFactor(), new RotatableSecret(secret, null));
            this.alloy = new Standalone(new StandaloneConfiguration(new StandardSecrets(null, List.of()),
                                                                    Map.of(),
                                                                    Map.of(SECRET_PATH, vectorSecret)));
        } catch (AlloyException e) {
            throw new IllegalArgumentException("Invalid Cloaked AI secret in " + config.secretFile(), e);
        }
        this.vectors = alloy.vector();
        this.metadata = AlloyMetadata.newSimple(new TenantId(config.tenantId()));
    }

    String vectorField() { return config.vectorField(); }
    String metadataField() { return config.metadataField(); }
    String queryFeature() { return "query(" + config.queryInput() + ")"; }

    EncryptedVector encryptDocumentVector(float[] plaintext) {
        return vectors.encrypt(new PlaintextVector(plaintext, SECRET_PATH, DERIVATION_PATH), metadata).join();
    }

    float[] encryptQueryVector(float[] plaintext) {
        var query = new PlaintextVectors(Map.of(QUERY_ID, new PlaintextVector(plaintext, SECRET_PATH, DERIVATION_PATH)));
        List<EncryptedVector> encrypted = vectors.generateQueryVectors(query, metadata).join().value().get(QUERY_ID);
        if (encrypted.size() != 1)
            throw new IllegalStateException("Expected one query vector for the single configured secret, got " + encrypted.size());
        return encrypted.getFirst().encryptedVector();
    }

    @Override
    public void deconstruct() {
        metadata.close();
        vectors.close();
        alloy.close();
    }

    private static byte[] readSecret(Path file) {
        try {
            return Base64.getDecoder().decode(Files.readString(file).strip());
        } catch (IOException e) {
            throw new UncheckedIOException("Could not read the Cloaked AI secret file " + file, e);
        }
    }

}
