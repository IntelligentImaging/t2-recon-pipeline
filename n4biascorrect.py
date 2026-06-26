#!/usr/bin/env python

""" Applies N4BiasFieldImageFilter to an image. """

import sys
import os
import argparse
import SimpleITK as sitk

def main(args):
    parser = argparse.ArgumentParser(description='Applies N4 bias correciton with sITK')
    parser.add_argument('-i', '--input', type=str, help='Specify input image')
    parser.add_argument('-o', '--output', type=str, help='Specify output image')
    parser.add_argument('-s', '--shrink', type=str, help='Specify shrink factor')
    parser.add_argument('-m', '--mask', type=str, help='Provide mask for bias correction')
    parser.add_argument('-n', '--iter', type=str, help='Set number of correction iterations')
    parser.add_argument('-l', '--levels', type=str, help='Set number of fitting levels')

    args = parser.parse_args()

    # Check if all required options are provided
    if not all([args.input, args.output]):
        parser.print_help()
        return

    image = sitk.ReadImage(args.input, sitk.sitkFloat32)

    if args.mask is not None:
        maskImage = sitk.ReadImage(args.mask, sitk.sitkUInt8)
    else:
        maskImage = sitk.OtsuThreshold(image, 0, 1, 200) # this thresholds the image, value may need to be adjusted, default was 200
        #sitk.WriteImage(maskImage, 'otsu.nii.gz')

    shrinkFactor = 1
    if args.shrink is not None:
        shrinkFactor = int(args.shrink)
        if shrinkFactor > 1:
            image = sitk.Shrink(image, [shrinkFactor] * image.GetDimension())
            maskImage = sitk.Shrink(
                maskImage, [shrinkFactor] * image.GetDimension()
            )

    corrector = sitk.N4BiasFieldCorrectionImageFilter()

    numberFittingLevels = 4
    if args.levels is not None:
        numberFittingLevels = int(args.levels)

    if args.iter is not None:
        corrector.SetMaximumNumberOfIterations([int(args.iter)] * numberFittingLevels)

    print('mask =', args.mask, ', shrink =', shrinkFactor, ', fittinglevels =', numberFittingLevels, ', iterations =', args.iter)
    corrected_image = corrector.Execute(image, maskImage)

    print(image)
    log_bias_field = corrector.GetLogBiasFieldAsImage(image)

    corrected_image_full_resolution = image / sitk.Exp(log_bias_field)

    sitk.WriteImage(corrected_image_full_resolution, args.output)

    if shrinkFactor > 1:
        sitk.WriteImage(
            corrected_image, "Python-Example-N4BiasFieldCorrection-shrunk.nrrd"
        )

    return_images = {
        "input_image": image,
        "mask_image": maskImage,
        "log_bias_field": log_bias_field,
        "corrected_image": corrected_image,
    }


if __name__ == "__main__":
    main(sys.argv[1:])




