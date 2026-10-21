package com.ironcorelabs.vespa.cloakedai;

import com.ironcorelabs.ironcore_alloy_java.EncryptedVector;
import com.yahoo.component.annotation.Inject;
import com.yahoo.docproc.DocumentProcessor;
import com.yahoo.docproc.Processing;
import com.yahoo.document.Document;
import com.yahoo.document.DocumentOperation;
import com.yahoo.document.DocumentPut;
import com.yahoo.document.DocumentUpdate;
import com.yahoo.document.Field;
import com.yahoo.document.datatypes.Raw;
import com.yahoo.document.datatypes.TensorFieldValue;

/**
 * Replaces the plaintext vector of each fed document with its Cloaked AI encryption, and stores the metadata
 * needed to decrypt it. Rejects updates to the vector field.
 */
public class EncryptVectorsDocumentProcessor extends DocumentProcessor {

    private final CloakedAi cloakedAi;

    @Inject
    public EncryptVectorsDocumentProcessor(CloakedAi cloakedAi) {
        this.cloakedAi = cloakedAi;
    }

    @Override
    public Progress process(Processing processing) {
        for (DocumentOperation operation : processing.getDocumentOperations()) {
            if (operation instanceof DocumentPut put) {
                encrypt(put.getDocument());
            } else if (operation instanceof DocumentUpdate update && updatesVectorField(update)) {
                return Progress.PERMANENT_FAILURE.withReason(
                        "Updates to the encrypted field '" + cloakedAi.vectorField() + "' are not supported; put the whole document");
            }
        }
        return Progress.DONE;
    }

    private void encrypt(Document document) {
        Field vectorField = document.getField(cloakedAi.vectorField());
        if (vectorField == null) return;
        if (!(document.getFieldValue(vectorField) instanceof TensorFieldValue value) || value.getTensor().isEmpty()) return;

        DenseVector plaintext = DenseVector.from(value.getTensor().get(), vectorField.getName());
        EncryptedVector encrypted = cloakedAi.encryptDocumentVector(plaintext.values());
        document.setFieldValue(vectorField, new TensorFieldValue(plaintext.withValues(encrypted.encryptedVector()).toTensor()));
        document.setFieldValue(cloakedAi.metadataField(), new Raw(encrypted.pairedIclInfo().value()));
    }

    private boolean updatesVectorField(DocumentUpdate update) {
        String name = cloakedAi.vectorField();
        return update.fieldUpdates().stream().anyMatch(fieldUpdate -> fieldUpdate.getField().getName().equals(name))
            || update.fieldPathUpdates().stream().anyMatch(pathUpdate -> rootField(pathUpdate.getOriginalFieldPath()).equals(name));
    }

    private static String rootField(String fieldPath) {
        return fieldPath.split("[.{\\[]", 2)[0];
    }

}
