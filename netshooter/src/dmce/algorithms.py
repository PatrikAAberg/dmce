import numpy as np
import sys
import os

def produceCotton(dfile, lfile, outpath, nex, verbose):
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
        sys.exit(1)

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
        labels = labels + labels
        nlabels = len(labels)

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

    # We might want to check here the cotton examples for being duplicates
    # to examples in the original dataset, but it is time consuming
    # and is deemed to not happen often enough to make a statistical difference

    outdata = data[0:nex * nelem]
    if verbose:
        print("Writing " + str(nex) + " cotton examples to " + outpath + "/data")
    outdata.astype('int32').tofile(outpath + "/data")

    with open(outpath + "/labels", 'w') as f:
        for i in range(0, nex):
            f.write("0\n")
    f.close()

