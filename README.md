## hls-base

This repository contains a base Dockerfile for shared libraries for HLS landast and sentinel processing.

The `lasrc` and `hls` code requires a number of [dependencies](https://github.com/developmentseed/espa-surface-reflectance/tree/master/lasrc#dependencies). To manage these dependencies in a more streamlined way the `Dockerfile` uses a base image which can be built using the `usgs.espa.centos.external` template defined in the [espa-dockerfiles](https://github.com/developmentseed/espa-dockerfiles) repository.

See the instructions in the [espa-dockerfiles](https://github.com/developmentseed/espa-dockerfiles) repository for building the external dependencies image.

After building the dependencies image, following the steps outlined [here](https://docs.aws.amazon.com/AmazonECR/latest/userguide/ECR_AWSCLI.html) you can tag this image as `552819999234.dkr.ecr.us-east-1.amazonaws.com/espa/external` and push it to ECR.


After building your dependencies image and pushing it to ECR you can build the `hls-base` image with

```shell
$ docker build --tag hls-base .
```

You can then tag this `hls-base` image as `350996086543.dkr.ecr.us-west-2.amazonaws.com/hls-base` and push it to ECR.

