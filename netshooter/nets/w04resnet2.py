# resnet2
#
# Convnet using skip-over layers

import numpy as np
import tensorflow.keras as keras
from tensorflow.keras.models import Sequential, Model
from tensorflow.keras.layers import Add, concatenate, Input, InputLayer, Reshape, Dense, Dropout, Conv1D
from tensorflow.keras.layers import MaxPooling1D, Concatenate, Lambda, PReLU, GlobalAveragePooling1D

def get_model(num_classes, num_probes, features):

    # this one should give us about 100 features after the 5th max pooling layer
    pn = int((num_probes / 100.0)**(1.0/5))

#    np.random.seed(5)

    # Filter scale
    scf = 0.4

    # network part 3
    padstr='same'

    model_m_inputs = Input(shape=(num_probes, features))
    mm = Conv1D( int(100 * scf), 7, activation='relu', padding='same')(model_m_inputs)

    mm = MaxPooling1D(pn)(mm)
    
    short = mm
    mm = Conv1D( int(100 * scf), 3, padding='same')(mm)
    mm = Add()([mm, short])
    mm = PReLU()(mm)
    
    mm = MaxPooling1D(pn)(mm)
    
    mm = Conv1D( int(200 * scf), 3, padding='same')(mm)
    mm = PReLU()(mm)
    
    short = mm
    mm = Conv1D( int(200 * scf), 3, padding='same')(mm)
    mm = Add()([mm, short])
    mm = PReLU()(mm)

    short = mm
    mm = Conv1D( int(200 * scf), 3, padding='same')(mm)
    mm = Add()([mm, short])
    mm = PReLU()(mm)

    mm = MaxPooling1D(pn)(mm)

    short = mm
    mm = Conv1D( int(200 * scf), 3, padding='same')(mm)
    mm = Add()([mm, short])
    mm = PReLU()(mm)
    mm = MaxPooling1D(pn)(mm)
    
    mm = Conv1D( int(100 * scf), 3, padding='same')(mm)
    mm = PReLU()(mm)

    short = mm
    mm = Conv1D( int(100 * scf), 3, padding='same')(mm)
    mm = Add()([mm, short])
    mm = PReLU()(mm)
    mm = MaxPooling1D(pn)(mm)
    
    short = mm
    mm = Conv1D( int(100 * scf), 3, padding='same')(mm)
    mm = Add()([mm, short])
    mm = PReLU()(mm)
    
    mm = GlobalAveragePooling1D()(mm)
    model_m_outputs = Dense(num_classes, activation='sigmoid')(mm)
    
    model_m = Model(model_m_inputs, model_m_outputs)
    print(model_m.summary())

    return model_m

# end of file
