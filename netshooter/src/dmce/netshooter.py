import numpy as np
import sys
import os
import importlib
import tensorflow.keras as keras
from tensorflow.keras.models import Model
from tensorflow.keras.models import load_model
from tensorflow.keras.callbacks import CSVLogger
import tensorflow as tf
import pickle

labels_train = None
data_train = None
netmodule = None
gpustrategy = None

def produceCotton(dfile, lfile, outfile, nex, verbose):
    np.set_printoptions(threshold=sys.maxsize)

    if verbose:
        print("Checking number of labels in " + lfile)
    lf = open(lfile)
    labels = lf.readlines()
    nlabels = len(labels)
    lf.close()

    if verbose:
        print("Reading examples from " + dfile)
    indata = np.fromfile(dfile, dtype=np.int32)

    if (len(indata) % nlabels != 0):
        print("Number of labels does not match data size, abort")

    nelem = int(len(indata) / nlabels)

    if verbose:
        print("Number of labels: " + str(nlabels))
        print("Number of elements: " + str(nelem))

    nconcats = int(nex / nlabels)

    if verbose:
        print("Making buffer large enough")
    data = indata
    for i in range(nconcats):
        if verbose:
            print("concats: " + str(i + 1))
        data = np.concatenate((indata, data))

    indata = np.copy(data)

    if verbose:
        print("")
        print("Clearing out every 7'th element...")
    data[0::7] = 0

    if verbose:
        print("Clearing out every 11'th element...")
    data[0::11] = 0

    if verbose:
        print("Clearing out every 13'th element...")
    data[0::13] = 0

    if verbose:
        print("Clearing out every 17'th element...")
    data[0::17] = 0

    data = np.reshape(data, (nlabels, nelem))
    indata = np.reshape(indata, (nlabels, nelem))
    outdata = np.array([])
    found = 0
    i = 0
    if verbose:
        print("Checking for duplicates")
    while (found < nex and i < nlabels):
        if verbose and i%100 == 0:
            print("Checked: " + str(i) + "    found: " + str(found))

        if not np.all((data == 0)):
            equal = indata[i] == data[i]
            if not equal.all():
                outdata = np.concatenate((outdata, data[i]))
                found+=1
        i+=1

    # We might want to check here the cotton examples for being duplicates
    # to examples in the original dataset, but it is time consuming
    # and is deemed to not happen often enough to make a statistical difference

    outdata = np.matrix.flatten(outdata)
    outdata = outdata[0:nex * nelem]
    if verbose:
        print("Writing " + str(nex) + " cotton examples to " + outfile)
    outdata.astype('int32').tofile(outfile)

def setupGPUs():
    global gpustrategy
    gpus = tf.config.list_physical_devices('GPU')
    gpu_device_list = []
    for i in range(len(gpus)):
        # Uncomment below line to be able to run on a 2080RTX wihtout telling
        # the TF container to do this on the docker run command line
        #
        #    tf.config.experimental.set_memory_growth(gpus[i], True)
        gpu_device_list.append("/gpu:{}".format(i))

    if len(gpus) > 1:
        gpustrategy = tf.distribute.MirroredStrategy(devices=gpu_device_list)
    else:
        gpustrategy = tf.distribute.MirroredStrategy()


class NetShooterData():

    name = None
    model = None
    batchsize = None
    csv = None
    regression = None
    merge = False
    epochs = None
    net = None
    delim = None
    features = None
    valsplit = None
    corlimit = None
    num_classes = None
    num_labels = None
    num_probes = None
    classes = None
    data_min_array = None
    data_max_array = None
    data_divider_array = None
    labels_min_array = None
    labels_max_array = None
    labels_divider_array = None
    delimiter = None
    verbose = False

    def setVerbose(self, verbose):
        self.verbose = verbose

    # binary_relative_interval_accuracy
    def briacc(self, y_true, y_pred):

        num_outputs = tf.shape(y_true)
        const_trues = tf.fill(num_outputs, True)
        const_falses = tf.fill(num_outputs, False)

        absdiff = tf.abs(tf.subtract(y_pred, y_true))

        error = tf.math.divide_no_nan(absdiff, y_true)

        errvec = tf.where(tf.greater(error, 0.02), const_falses, const_trues)
        correct = tf.math.count_nonzero(errvec)
        whole = tf.math.count_nonzero(const_trues)
        correct = tf.cast(correct, dtype=tf.float32)
        whole = tf.cast(whole, dtype=tf.float32)
        bia = tf.math.divide_no_nan(correct, whole)

        return bia

    # binary_absolute_interval_accuracy
    baiacc_correctness_limit = 0.05

    def baiacc(self, y_true, y_pred):

        num_outputs = tf.shape(y_true)
        const_trues = tf.fill(num_outputs, True)
        const_falses = tf.fill(num_outputs, False)

        absdiff = tf.abs(tf.subtract(y_pred, y_true))

        # Change 100 to whatever absolute error you want to check for
        errvec = tf.where(tf.greater(absdiff, baiacc_correctness_limit), const_falses, const_trues)
        correct = tf.math.count_nonzero(errvec)
        whole = tf.math.count_nonzero(const_trues)
        correct = tf.cast(correct, dtype=tf.float32)
        whole = tf.cast(whole, dtype=tf.float32)
        bia = tf.math.divide_no_nan(correct, whole)

        return bia

    def binary_cross_accuracy(self, y_true, y_pred):

        const_trues = tf.fill(tf.shape(y_true), True)
        const_falses = tf.fill(tf.shape(y_true), False)

        y_true_bool = tf.where(tf.greater(y_true, 0.5), const_trues, const_falses)
        y_pred_bool = tf.where(tf.greater(y_pred, 0.5), const_trues, const_falses)

        y_or = tf.math.logical_or(y_true_bool, y_pred_bool)
        y_and = tf.math.logical_and(y_true_bool, y_pred_bool)

        found = tf.math.count_nonzero(y_or)
        correct = tf.math.count_nonzero(y_and)
        found = tf.cast(found, dtype=tf.float32)
        correct = tf.cast(correct, dtype=tf.float32)

        bca = tf.math.divide_no_nan(correct, found)
        return bca

    custom_objects = dict()
    custom_objects["binary_cross_accuracy"] = binary_cross_accuracy
    custom_objects["baiacc"] = baiacc
    custom_objects["briacc"] = briacc

    def binaryCrossAccuracy(self, labels_train, labels_pred):

        etotal = 0
        ntotal = 0
        num_labels = np.shape(labels_train)[0]
        print(num_labels)
        for i in range(num_labels):
            errfound = False
            for j in range(self.num_classes):
                if (labels_pred[i, j] != labels_train[i, j]):
                    etotal += 1
                    errfound = True
                ntotal += 1
            if errfound and self.verbose:
                print("Example " + str(i) + ": " + str(labels_train[i,:]) + " => " + str(labels_pred[i,:]))
        return 1 - float(etotal) / float(ntotal)

    def suggestMerges(self, confmatrix, precision, skiplist):
        confmatrix = confmatrix[:,:-1]
        merges = []
        for i in range (self.num_classes):
            for j in range (i , self.num_classes ):
                if (i != j) and (i not in skiplist):
                    err = confmatrix[i, j] + confmatrix[j, i]
                    tot = err + confmatrix[i, i] + confmatrix[j, j]
                    if (float(err) / float(tot) > float(precision)):
                        # merge
                        merges.append([i, j])

        return merges

    def printConfMatrix(self, confmatrix):
        print("")
        print("Confusion matrix for model '{}'".format(self.name))
        for i in range(self.num_classes):
            print("")
            for j in range(self.num_classes + 1):
                out = str(int(confmatrix[i, j]))
                print(f'{out:>10}', end = " "),

        print("")
        print("")
        print("facit on Y-axis, prediction on X-axis. Only valid for labels with one class per example")
        print("no class found is handled by the right-most column")
        print("")

    def confmatrix(self, labels_train, labels_pred):

        confmatrix = np.zeros((self.num_classes, self.num_classes + 1))

        for i in range(len(labels_train)):
            # if no class found, increase right-most value
            pc_arr = []
            for j in range(self.num_classes):
                if (labels_train[i, j] > 0):
                    lc = j

                if (labels_pred[i, j] > 0):
                     pc_arr.append(j)

            if len(pc_arr) > 0:
                for k in pc_arr:
                    confmatrix[lc, k] += 1
            else:
                # right most column
                confmatrix[lc, self.num_classes] += 1
        return confmatrix

    def labelsLoad(self, flabels):
        if self.verbose:
            print("Read labels from: " + flabels)

        lfile = open(flabels)
        labels = lfile.readlines()
        num_labels = len(labels)
        lfile.close()

        labels_onehot = np.zeros((num_labels, self.num_classes))
        for i in range(num_labels):
            labelslist = labels[i].split()
            for j in range(len(labelslist)):
                pos=int(labelslist[j])
                labels_onehot[i][pos] = 1
        return labels_onehot, num_labels


    def dataLoad(self, fdata):
        if self.verbose:
            print("Read data from: " + fdata)

        if self.csv:
            data = np.loadtxt(fdata, delimiter=self.delimiter)
        else:
            data = np.fromfile(fdata, dtype=np.int32)

        data = np.matrix.flatten(data)
        total_num_probes = len(data)
        num_labels = int(total_num_probes / (self.num_probes * self.features))
        data = np.reshape(data, (num_labels, self.num_probes, self.features))

        # normalize if csv
        if self.csv:
            data = self.normalize(data)

        # sanity check data size
        if ( (self.num_probes * num_labels * self.features) != total_num_probes ):
            print("error: number of labels and features does not match total number of probes!")
            sys.exit (1)

        return data

    def load(self, path):
        if (self.verbose):
            print("netshooter: loading from path " + path)
        with open(path + "/netshooter.bin", 'rb') as f:
            nsinstance = pickle.load(f)
            nsinstance.model = load_model(path + "/netshooter-model.h5", custom_objects = self.custom_objects)
            f.close()

        if self.verbose:
            print("---------------------------------------------------------------------------------------")
            print("Loading model info from " + path + "/netshooter.bin")
            print("Netshooter info")
            print("    name:        " + str(nsinstance.name))
            print("    batchsize:   " + str(nsinstance.batchsize))
            print("    csv:         " + str(nsinstance.csv))
            print("    regression:  " + str(nsinstance.regression))
            print("    epochs:      " + str(nsinstance.epochs))
            print("    net:         " + str(nsinstance.net))
            print("    delim:       " + ">" + str(nsinstance.delim) + "<")
            print("    features:    " + str(nsinstance.features))
            print("    numprobes:   " + str(nsinstance.num_probes))
            print("    valsplit:    " + str(nsinstance.valsplit))
            print("    corlimit:    " + str(nsinstance.corlimit))

            print("Class names")
            for name in nsinstance.classes:
                print("     " + name)

            return nsinstance

    def __save(self, modelpath):
        filename = modelpath + "/netshooter.bin"
        if (self.verbose):
            print("netshooter: saving " + filename)
        with open(filename, 'wb') as f:
            pickle.dump(self, f)
            f.close()

    def normalize(self, data):
        print("Data min-max transform arrays used per feature:")
        print("Min:               " + str(self.data_min_array))
        print("Max:               " + str(self.data_max_array))
        print("Divider (Max-min): " + str(self.data_divider_array))

        for i in range(0, self.features):
            data[:,:,i] = (data[:,:,i] - self.data_min_array[i]) / self.data_divider_array[i]
        return data

    def predict(self, data):
        if (self.verbose):
            print("netshooter: predicting")
        return self.model.predict(data)


    def __configParam(self, paramline):
        paramline = paramline.rstrip("\n")
        if paramline[0] == '#':
            return

        pl = paramline.split(":")
        p = pl[0]
        val = pl[1]

        if      (p == "name"):
            self.name = val
        elif    (p == "batchsize"):
            self.batchsize = int(val)
        elif    (p == "csv"):
            if (val == "True"):
                self.csv = True
            else:
                self.csv = False
        elif    (p == "regression"):
            if (val == "True"):
                self.regression = True
            else:
                self.regression = False
        elif    (p == "merge"):
            if (val == "True"):
                self.merge = True
            else:
                self.merge = False
        elif    (p == "epochs"):
            self.epochs = int(val)
        elif    (p == "net"):
            self.net = val
        elif    (p == "delim"):
            self.delim = val
        elif    (p == "features"):
            self.features = int (val)
        elif    (p == "valsplit"):
            self.valsplit = float(val)
        elif    (p == "corlimit"):
            self.corlimit = float(val)
        elif (p == "numprobes"):
            self.num_probes = float(val)

    def __printConfig(self):
        print("    name:        " + str(self.name))
        print("    batchsize:   " + str(self.batchsize))
        print("    csv:         " + str(self.csv))
        print("    regression:  " + str(self.regression))
        print("    epochs:      " + str(self.epochs))
        print("    net:         " + str(self.net))
        print("    delim:       " + ">" + str(self.delim) + "<")
        print("    features:    " + str(self.features))
        print("    numprobes:   " + str(self.num_probes))
        print("    valsplit:    " + str(self.valsplit))
        print("    corlimit:    " + str(self.corlimit))

    def __readConfig(self, cfile):
        try:
            with open(cfile, 'r') as f:
                config = f.readlines()
        except:
            print("No config file found at " + cfile + ", abort")
            sys.exit(1)

        for cl in config:
            self.__configParam(cl)

    def __readClasses(self, cfile):
        # Read classes list file
        if os.path.exists(cfile):
            cl = open(cfile)
            self.classes = cl.read().splitlines()
            cl.close()
            self.num_classes = len(self.classes)
            print("Read " + str(self.num_classes) + " classes from " + cfile)
        else:
            # num classes is used as num_outputs when doing regression for future prediction, clean this up if other regression is needed
            num_classes = self.features;
            print(cfile + " not found, setting number of classes to number of features (feature prediction use-case)")

    def getClassName(self, ind):
        return self.classes[ind]

    def __readDataAndLabels(self, dfile, lfile):
        global data_train
        global labels_train

        print("Checking number of labels in " + lfile)
        lf = open(lfile)
        labels = lf.readlines()
        self.num_labels = len(labels)
        lf.close()

        self.labels_min_array = []
        self.labels_max_array = []
        self.labels_divider_array = []
        self.data_min_array = []
        self.data_max_array = []
        self.data_divider_array = []

        if (self.csv):
            print("Reading csv data from " + dfile)
            data = np.loadtxt(dfile, delimiter=self.delim)
            data = np.matrix.flatten(data)
            total_num_probes = len(data)
            self.num_probes = int(total_num_probes / (self.num_labels * self.features))
            data = np.reshape(data, (self.num_labels, self.num_probes, self.features))

            # Normalize data per collumn
            for i in range(0, self.features):
                self.data_min_array.append(np.min(data[:,:,i]))
                self.data_max_array.append(np.max(data[:,:,i]))
                self.data_divider_array.append(np.max(data[:,:,i]) - np.min(data[:,:,i]) )
                data[:,:,i] = (data[:,:,i] - self.data_min_array[i]) / self.data_divider_array[i]

            print("Data min-max transform arrays per feature for inference input:")
            print("Min:               " + str(self.data_min_array))
            print("Max:               " + str(self.data_max_array))
            print("Divider (Max-min): " + str(self.data_divider_array))

            print("Reading csv labels from " + lfile)

            if self.regression:
                labels_train = np.loadtxt(lfile, delimiter=self.delim)
                # Normalize labels per feature
                for i in range(0, self.features):
                    self.labels_min_array.append(np.min(labels_train[:,i]))
                    self.labels_max_array.append(np.max(labels_train[:,i]))
                    self.labels_divider_array.append(np.max(labels_train[:,i]) - np.min(labels_train[:,i]) )
                    labels_train[:,i] = (labels_train[:,i] - self.labels_min_array[i]) / self.labels_divider_array[i]

                print("Labels min-max transform arrays per feature for inference output:")
                print("Min:               " + str(self.labels_min_array))
                print("Max:               " + str(self.labels_max_array))
                print("Divider (Max-min): " + str(self.labels_divider_array))

            else:
                labels_train = np.zeros((self.num_labels, self.num_classes))
                for i in range(self.num_labels):
                    labelslist = labels[i].split()
                    for j in range(len(labelslist)):
                        pos=int(labelslist[j])
                        labels_train[i][pos] = 1

        else:
            print("Reading binary data from " + dfile)
            data = np.fromfile(dfile, dtype=np.int32)

            labels_train = np.zeros((self.num_labels, self.num_classes))

            for i in range(self.num_labels):
                labelslist = labels[i].split()
                for j in range(len(labelslist)):
                    pos=int(labelslist[j])
                    labels_train[i][pos] = 1


        data = np.matrix.flatten(data)
        total_num_probes = len(data)

        print("Found " + str(self.num_labels) + " labels")
        print("Found " + str(total_num_probes) + " probes")
        print("Found " + str(self.num_classes) + " classes")
        print("Found " + str(self.features) + " features")

        self.num_probes = int(total_num_probes / (self.num_labels * self.features))

        if ( (self.num_probes * self.num_labels * self.features) != total_num_probes ):
            print("Number of labels and features does not match total number of probes!")
            sys.exit (1)

        data_train = np.reshape(data, (self.num_labels, self.num_probes, self.features))
        print("Data train shape")
        print(np.shape(data_train))

    def __buildAndFit(self, datapath, modelpath):
        global data_train
        global labels_train
        global netmodule
        global gpustrategy

        parent = self
        class EpochPrint(keras.callbacks.Callback):
            def on_epoch_end(self, batch, logs={}):
                print(" datapath[in]: {} modelpath[out]: {} net: {}".format(datapath, modelpath, parent.net))
        epoch_callback = EpochPrint()

        baiacc = self.baiacc
        binary_cross_accuracy = self.binary_cross_accuracy

        with gpustrategy.scope():
            model = netmodule.get_model(self.num_classes, self.num_probes, self.features)
            csv_logger = CSVLogger(modelpath + '/results.csv', separator=';')
            if self.regression:
                model.compile(loss='mse', optimizer='adam', metrics=[baiacc])
                callbacks_list = [ keras.callbacks.ModelCheckpoint(filepath=modelpath + '/netshooter-model.h5', monitor='baiacc', save_best_only=True), epoch_callback, csv_logger]
            else:
                model.compile(loss='binary_crossentropy', optimizer='adam', metrics=[binary_cross_accuracy])
                callbacks_list = [ keras.callbacks.ModelCheckpoint(filepath=modelpath + '/netshooter-model.h5', monitor='binary_cross_accuracy', save_best_only=True), keras.callbacks.EarlyStopping(monitor='binary_cross_accuracy', patience=1000), epoch_callback, csv_logger]
        print(np.shape(data_train))
        print(np.shape(labels_train))

        # Merge enabled?
        if self.merge:
            continueTrain = True
            while continueTrain:
                history = model.fit(data_train, labels_train, batch_size=self.batchsize, epochs=self.epochs, callbacks=callbacks_list, validation_split=self.valsplit, verbose=1)

                # Produce confusion matrix
                pred = model.predict(data_train)
                pred[pred >= 0.5] = 1
                pred[pred < 0.5] = 0
                labels_predict = pred

                confmatrix = self.confmatrix(labels_train, labels_predict)
                self.printConfMatrix(confmatrix)
                merges = self.suggestMerges(confmatrix, 0.1, [])

                print("Suggested merges:")
                print(merges)
                continueTrain = False
        else:
            # just run once
            history = model.fit(data_train, labels_train, batch_size=self.batchsize, epochs=self.epochs, callbacks=callbacks_list, validation_split=self.valsplit, verbose=1)

        with open(modelpath + "/netshooter.info", 'w') as f:
            f.write("Name:" + self.name + "\n")
            for c in range(len(self.classes)):
                f.write("Class:" + str(c) + ":" + self.classes[c] + "\n")
        self.__save(modelpath)
        model.save(modelpath + "/netshooter-model.h5")


    def train(self, datapath, modelpath):
        global netmodule
        print("Start training")
        print("==============")
        print("  Data path: " + datapath)
        print("  Model path: " + modelpath)
        print("  Config:")
        self.__readConfig(datapath + "/.config")
        self.__printConfig()

        try:
            netmodule = importlib.import_module(self.net)
            print("Sucessfully imported " + self.net)
        except:
            print("Failed to import net: " +self.net + ", abort")
            sys.exit(1)

        self.__readClasses(datapath + "/classes")

        self.__readDataAndLabels(datapath + "/data", datapath + "/labels")
        setupGPUs()
        self.__buildAndFit(datapath, modelpath)

        with open(datapath + "/.config", 'r') as f:
            config = f.readlines()
        f.close()

        with open(modelpath + "/.config", 'w') as f:
            config = f.writelines(config)
        f.close()


# EOF
