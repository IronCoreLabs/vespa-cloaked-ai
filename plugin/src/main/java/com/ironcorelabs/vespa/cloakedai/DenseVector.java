package com.ironcorelabs.vespa.cloakedai;

import com.yahoo.tensor.IndexedTensor;
import com.yahoo.tensor.Tensor;
import com.yahoo.tensor.TensorType;

/** A tensor&lt;float&gt;(x[N]) value as the float[] alloy works on. */
record DenseVector(TensorType type, float[] values) {

    static DenseVector from(Tensor tensor, String name) {
        TensorType type = tensor.type();
        if (type.rank() != 1 || !type.hasOnlyIndexedBoundDimensions() || type.valueType() != TensorType.Value.FLOAT)
            throw new IllegalArgumentException(name + " must be a tensor<float>(x[N]), but is " + type);
        IndexedTensor indexed = (IndexedTensor) tensor;
        float[] values = new float[(int) indexed.size()];
        for (int i = 0; i < values.length; i++)
            values[i] = indexed.getFloat(i);
        return new DenseVector(type, values);
    }

    DenseVector withValues(float[] newValues) {
        return new DenseVector(type, newValues);
    }

    Tensor toTensor() {
        return IndexedTensor.Builder.of(type, values).build();
    }

}
