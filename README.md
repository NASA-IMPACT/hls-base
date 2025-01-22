## hls-base
This repository contains a base Dockerfile for shared libraries for HLS Landast and Sentinel processing.

### Pre-requisites
The `LaSRC` and `HLS` code require a number of [dependencies](https://github.com/nasa-impact/espa-surface-reflectance/tree/master/lasrc#dependencies). To manage these dependencies in a more streamlined way the `Dockerfile` uses a base image which can be built using the `usgs.espa.centos.external` template defined in the [espa-dockerfiles](https://github.com/nasa-impact/espa-dockerfiles) repository.

See the instructions in the [espa-dockerfiles](https://github.com/nasa-impact/espa-dockerfiles) repository for building the external dependencies image.

Specifically, you will need to run `make centos.base` and `make centos.external`.

After building the dependencies image, following the steps outlined [here](https://docs.aws.amazon.com/AmazonECR/latest/userguide/ECR_AWSCLI.html) you can tag this image as `018923174646.dkr.ecr.us-west-2.amazonaws.com/espa/external` and push it to ECR.


### CI
The repository contains two CI workflows. When a PR is created to dev a new image is created and pushed to the hls-base ECR repository with a tag that has the same number as the PR

When a new release is created from `master` a new image is created and pushed to the hls-base ECR with a tag that is the same as the release name.
