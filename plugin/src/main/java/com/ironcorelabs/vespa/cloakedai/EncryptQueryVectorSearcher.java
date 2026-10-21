package com.ironcorelabs.vespa.cloakedai;

import com.yahoo.component.annotation.Inject;
import com.yahoo.search.Query;
import com.yahoo.search.Result;
import com.yahoo.search.Searcher;
import com.yahoo.search.query.ranking.RankFeatures;
import com.yahoo.search.searchchain.Execution;
import com.yahoo.tensor.Tensor;

import java.util.Optional;

/** Replaces the plaintext query vector input with its Cloaked AI encryption, so it can be matched against encrypted documents. */
public class EncryptQueryVectorSearcher extends Searcher {

    private final CloakedAi cloakedAi;

    @Inject
    public EncryptQueryVectorSearcher(CloakedAi cloakedAi) {
        this.cloakedAi = cloakedAi;
    }

    @Override
    public Result search(Query query, Execution execution) {
        String feature = cloakedAi.queryFeature();
        RankFeatures features = query.getRanking().getFeatures();
        Optional<Tensor> plaintextTensor = features.getTensor(feature);
        if (plaintextTensor.isPresent()) {
            DenseVector plaintext = DenseVector.from(plaintextTensor.get(), feature);
            features.put(feature, plaintext.withValues(cloakedAi.encryptQueryVector(plaintext.values())).toTensor());
        }
        return execution.search(query);
    }

}
