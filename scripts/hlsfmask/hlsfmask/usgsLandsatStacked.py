"""
Script that takes USGS landsat stacked separately for
reflective and thermal and runs the fmask on it.
"""
# This file is part of 'python-fmask' - a cloud masking module
# Copyright (C) 2015  Neil Flood
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 3
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
from __future__ import print_function, division

import os
import sys
import glob
import argparse
import tempfile
import subprocess
from fmask import landsatTOA
from fmask.cmdline import usgsLandsatMakeAnglesImage, usgsLandsatSaturationMask
from fmask import config
from fmask import fmaskerrors
from fmask import fmask

from rios import fileinfo
from rios.imagewriter import DEFAULTDRIVERNAME, dfltDriverOptions
from rios.parallel.jobmanager import find_executable

# for GDAL command line utilities
CMDLINECREATIONOPTIONS = []
if DEFAULTDRIVERNAME in dfltDriverOptions:
    for opt in dfltDriverOptions[DEFAULTDRIVERNAME]:
        CMDLINECREATIONOPTIONS.append('-co')
        CMDLINECREATIONOPTIONS.append(opt)

def getCmdargs():
    """
    Get command line arguments
    """
    parser = argparse.ArgumentParser()
    parser.add_argument('-t', '--thermal', help='Input stack of thermal bands')
    parser.add_argument('-a', '--toa',
        help='Input stack of TOA reflectance (see fmask_usgsLandsatTOA.py)')
    parser.add_argument('-m', '--mtl', help='Input .MTL file')
    parser.add_argument('-s', '--saturation',
        help='Input saturation mask (see fmask_usgsLandsatSaturationMask.py)')
    parser.add_argument("-z", "--anglesfile",
        help="Image of sun and satellite angles (see fmask_usgsLandsatMakeAnglesImage.py)")
    parser.add_argument('-o', '--output', dest='output',
        help='output cloud mask')
    parser.add_argument('-v', '--verbose', default=False,
        action='store_true', help='verbose output')
    parser.add_argument('-k', '--keepintermediates', dest='keepintermediates',
        default=False, action='store_true', help='verbose output')
    parser.add_argument('-e', '--tempdir',
        default='.', help="Temp directory to use (default=%(default)s)")
    parser.add_argument('--scenedir', help='Path to the unzipped USGS Landsat scene. ' +
        'Using this option will automatically create intermediate stacks of the input ' +
        'bands, and so does NOT require --toa, --thermal, --saturation, --mtl or --anglesfile')

    params = parser.add_argument_group(title="Configurable parameters", description="""
        Changing these parameters will affect the way the algorithm works, and thus the
        quality of the final output masks.
        """)
    params.add_argument("--mincloudsize", type=int, default=0,
        help="Mininum cloud size (in pixels) to retain, before any buffering. Default=%(default)s)")
    params.add_argument("--cloudbufferdistance", type=float, default=150,
        help="Distance (in metres) to buffer final cloud objects (default=%(default)s)")
    params.add_argument("--shadowbufferdistance", type=float, default=300,
        help="Distance (in metres) to buffer final cloud shadow objects (default=%(default)s)")
    defaultCloudProbThresh = 100 * config.FmaskConfig.Eqn17CloudProbThresh
    params.add_argument("--cloudprobthreshold", type=float, default=defaultCloudProbThresh,
        help=("Cloud probability threshold (percentage) (default=%(default)s). This is "+
            "the constant term at the end of equation 17, given in the paper as 0.2 (i.e. 20%%). "+
            "To reduce commission errors, increase this value, but this will also increase "+
            "omission errors. "))
    dfltNirSnowThresh = config.FmaskConfig.Eqn20NirSnowThresh
    params.add_argument("--nirsnowthreshold", default=dfltNirSnowThresh, type=float,
        help=("Threshold for NIR reflectance (range [0-1]) for snow detection "+
            "(default=%(default)s). Increase this to reduce snow commission errors"))
    dfltGreenSnowThresh = config.FmaskConfig.Eqn20GreenSnowThresh
    params.add_argument("--greensnowthreshold", default=dfltGreenSnowThresh, type=float,
        help=("Threshold for Green reflectance (range [0-1]) for snow detection "+
            "(default=%(default)s). Increase this to reduce snow commission errors"))
    stricFmask = config.FmaskConfig.strictFmask
    params.add_argument("--strict", default=strictFmask, type=bool,
        help=("Use strict Fmask setttings from base Fmask"+
            "(default=%(default)s). Set false to disable"))
    dfltDisplacement = config.sen2displacementTest
    params.add_argument("--displacement", default=dfltDisplacement, type=bool,
        help=("Use the Frantz (2018) parallax displacement test"+
            "(default=%(default)s). Set false to disable"))
    cmdargs = parser.parse_args()

    return cmdargs

def makeStacksAndAngles(cmdargs):
    """
    Find the name of the MTL file.
    Make an intermediate stacks of all the TOA reflectance and thermal bands.
    Also make an image of the angles, saturation and TOA reflectance.
    Fill in the names of these in the cmdargs object.

    """
    # find MTL file
    wldpath = os.path.join(cmdargs.scenedir, '*_MTL.txt')
    mtlList = glob.glob(wldpath)
    if len(mtlList) != 1:
        raise fmaskerrors.FmaskFileError("Cannot find a *_MTL.txt file in specified dir")

    cmdargs.mtl = mtlList[0]

    gdalmergeCmd = find_executable("gdal_merge.py")

    # we need to find the 'SPACECRAFT_ID' to work out the wildcards to use
    mtlInfo = config.readMTLFile(cmdargs.mtl)
    landsat = mtlInfo['SPACECRAFT_ID'][-1]

    if landsat == '4' or landsat == '5':
        refWildcard = 'L*_B[1,2,3,4,5,7].TIF'
        thermalWildcard = 'L*_B6.TIF'
    elif landsat == '7':
        refWildcard = 'L*_B[1,2,3,4,5,7].TIF'
        thermalWildcard = 'L*_B6_VCID_?.TIF'
    elif landsat == '8':
        refWildcard = 'LC*_B[1-7,9].TIF'
        thermalWildcard = 'LC*_B1[0,1].TIF'
    else:
        raise SystemExit('Unsupported Landsat sensor')

    wldpath = os.path.join(cmdargs.scenedir, refWildcard)
    refFiles = sorted(glob.glob(wldpath))
    if len(refFiles) == 0:
        raise fmaskerrors.FmaskFileError("Cannot find expected reflectance files for sensor")

    wldpath = os.path.join(cmdargs.scenedir, thermalWildcard)
    thermalFiles = sorted(glob.glob(wldpath))
    if len(thermalFiles) == 0:
        raise fmaskerrors.FmaskFileError("Cannot find expected thermal files for sensor")

    if cmdargs.verbose:
        print("Making stack of all reflectance bands")
    (fd, tmpRefStack) = tempfile.mkstemp(dir=cmdargs.tempdir, prefix="tmp_allrefbands_",
        suffix=".img")
    os.close(fd)

    # use sys.executable so Windows works
    subprocess.check_call([sys.executable, gdalmergeCmd, '-q', '-of', DEFAULTDRIVERNAME] +
            CMDLINECREATIONOPTIONS + ['-separate', '-o', tmpRefStack] + refFiles)

    # stash so we can delete later
    cmdargs.refstack = tmpRefStack

    if cmdargs.verbose:
        print("Making stack of all thermal bands")
    (fd, tmpThermStack) = tempfile.mkstemp(dir=cmdargs.tempdir, prefix="tmp_allthermalbands_",
        suffix=".img")
    os.close(fd)

    subprocess.check_call([sys.executable, gdalmergeCmd, '-q', '-of', DEFAULTDRIVERNAME] +
        CMDLINECREATIONOPTIONS + ['-separate', '-o', tmpThermStack] + thermalFiles)

    cmdargs.thermal = tmpThermStack

    # now the angles
    if cmdargs.verbose:
        print("Creating angles file")
    (fd, anglesfile) = tempfile.mkstemp(dir=cmdargs.tempdir, prefix="angles_tmp_",
        suffix=".img")
    os.close(fd)
    usgsLandsatMakeAnglesImage.makeAngles(cmdargs.mtl, tmpRefStack, anglesfile)
    cmdargs.anglesfile = anglesfile

    # saturation
    if cmdargs.verbose:
        print("Creating saturation file")
    (fd, saturationfile) = tempfile.mkstemp(dir=cmdargs.tempdir, prefix="saturation_tmp_",
        suffix=".img")
    os.close(fd)
    usgsLandsatSaturationMask.makeSaturationMask(cmdargs.mtl, tmpRefStack, saturationfile)
    cmdargs.saturation = saturationfile

    # TOA
    if cmdargs.verbose:
        print("Creating TOA file")
    (fs, toafile) = tempfile.mkstemp(dir=cmdargs.tempdir, prefix="toa_tmp_",
        suffix=".img")
    os.close(fd)
    landsatTOA.makeTOAReflectance(tmpRefStack, cmdargs.mtl, anglesfile, toafile)
    cmdargs.toa = toafile

def mainRoutine():
    """
    Main routine that calls fmask
    """
    cmdargs = getCmdargs()
    tempStack = False
    if cmdargs.scenedir is not None:
        tempStack = True
        makeStacksAndAngles(cmdargs)

    if (cmdargs.thermal is None or cmdargs.anglesfile is None or
            cmdargs.mtl is None is None or cmdargs.output is None
            or cmdargs.toa is None):
        raise SystemExit('Not all required input parameters supplied')

    # 1040nm thermal band should always be the first (or only) band in a
    # stack of Landsat thermal bands
    thermalInfo = config.readThermalInfoFromLandsatMTL(cmdargs.mtl)

    anglesfile = cmdargs.anglesfile
    anglesInfo = config.AnglesFileInfo(anglesfile, 3, anglesfile, 2, anglesfile, 1, anglesfile, 0)

    mtlInfo = config.readMTLFile(cmdargs.mtl)
    landsat = mtlInfo['SPACECRAFT_ID'][-1]

    if landsat == '4':
        sensor = config.FMASK_LANDSAT47
    elif landsat == '5':
        sensor = config.FMASK_LANDSAT47
    elif landsat == '7':
        sensor = config.FMASK_LANDSAT47
    elif landsat == '8':
        sensor = config.FMASK_LANDSAT8
    else:
        raise SystemExit('Unsupported Landsat sensor')

    fmaskFilenames = config.FmaskFilenames()
    fmaskFilenames.setTOAReflectanceFile(cmdargs.toa)
    fmaskFilenames.setThermalFile(cmdargs.thermal)
    fmaskFilenames.setOutputCloudMaskFile(cmdargs.output)
    if cmdargs.saturation is not None:
        fmaskFilenames.setSaturationMask(cmdargs.saturation)
    else:
        print('saturation mask not supplied - see fmask_usgsLandsatSaturationMask.py')

    fmaskConfig = config.FmaskConfig(sensor)
    fmaskConfig.setThermalInfo(thermalInfo)
    fmaskConfig.setAnglesInfo(anglesInfo)
    fmaskConfig.setKeepIntermediates(cmdargs.keepintermediates)
    fmaskConfig.setVerbose(cmdargs.verbose)
    fmaskConfig.setTempDir(cmdargs.tempdir)
    fmaskConfig.setMinCloudSize(cmdargs.mincloudsize)
    fmaskConfig.setEqn17CloudProbThresh(cmdargs.cloudprobthreshold / 100)    # Note conversion from percentage
    fmaskConfig.setEqn20NirSnowThresh(cmdargs.nirsnowthreshold)
    fmaskConfig.setEqn20GreenSnowThresh(cmdargs.greensnowthreshold)
    fmaskConfig.setStrictFmask(cmdargs.strict)
    fmaskConfig.setSen2displacementTest(cmdargs.displacement)

    # Work out a suitable buffer size, in pixels, dependent on the resolution of the input TOA image
    toaImgInfo = fileinfo.ImageInfo(cmdargs.toa)
    fmaskConfig.setCloudBufferSize(int(cmdargs.cloudbufferdistance / toaImgInfo.xRes))
    fmaskConfig.setShadowBufferSize(int(cmdargs.shadowbufferdistance / toaImgInfo.xRes))

    # Redefine output constants to match Fortran Fmask 4.0
    fmask.OUTCODE_NULL = 5
    fmask.OUTCODE_CLEAR = 0
    fmask.OUTCODE_CLOUD = 4
    fmask.OUTCODE_SHADOW = 2
    fmask.OUTCODE_SNOW = 3
    fmask.OUTCODE_WATER = 1

    fmask.doFmask(fmaskFilenames, fmaskConfig)

    if tempStack and not cmdargs.keepintermediates:
        for fn in [cmdargs.refstack, cmdargs.thermal, cmdargs.anglesfile,
                cmdargs.saturation, cmdargs.toa]:
            if os.path.exists(fn):
                os.remove(fn)