## hls-base
This repository contains a base Dockerfile for shared libraries for HLS landast and sentinel processing.

### Pre-requisites
The `lasrc` and `hls` code requires a number of [dependencies](https://github.com/nasa-impact/espa-surface-reflectance/tree/master/lasrc#dependencies). To manage these dependencies in a more streamlined way the `Dockerfile` uses a base image which can be built using the `usgs.espa.centos.external` template defined in the [espa-dockerfiles](https://github.com/nasa-impact/espa-dockerfiles) repository.

See the instructions in the [espa-dockerfiles](https://github.com/nasa-impact/espa-dockerfiles) repository for building the external dependencies image.

Specifically, you will need to run `make centos.base` and `make centos.external`.

After building the dependencies image, following the steps outlined [here](https://docs.aws.amazon.com/AmazonECR/latest/userguide/ECR_AWSCLI.html) you can tag this image as `018923174646.dkr.ecr.us-west-2.amazonaws.com/espa/external` and push it to ECR.


After building your dependencies image and pushing it to ECR you can build the `hls-base` image with:

```shell
$ docker build . --no-cache -t hls-base --build-arg lasrc_version=3.1.0
```
### CI
The repository contains two CI workflows. When commits are pushed to the collection2 branch a new image is built and pushed to ECR with no tag.

When a new release is created from collection2 a new image is built and pushed to ECR with the release version as a tag.
