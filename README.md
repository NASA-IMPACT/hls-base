## hls-base

This repository contains a base Dockerfile for shared libraries for HLS landast and sentinel processing.

### Pre-requisites

The `lasrc` and `hls` code requires a number of [dependencies](https://github.com/developmentseed/espa-surface-reflectance/tree/master/lasrc#dependencies). To manage these dependencies in a more streamlined way the `Dockerfile` uses a base image which can be built using the `usgs.espa.centos.external` template defined in the [espa-dockerfiles](https://github.com/developmentseed/espa-dockerfiles) repository.

See the instructions in the [espa-dockerfiles](https://github.com/developmentseed/espa-dockerfiles) repository for building the external dependencies image.

Specifically, you will need to run `make centos.base` and `make centos.external`.

After building the dependencies image, following the steps outlined [here](https://docs.aws.amazon.com/AmazonECR/latest/userguide/ECR_AWSCLI.html) you can tag this image as `<AWS_ACCOUNT_ID>.dkr.ecr.us-west-2.amazonaws.com/espa/external` and push it to ECR.


After building your dependencies image and pushing it to ECR you can build the `hls-base` image with:

```shell
$ docker build --no-cache --build-arg AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID}" -t hls-base .
```

Note: The command above assumes you have exported an environment variable `AWS_ACCOUNT_ID` which references the AWS account where the espa/external reference image is stored.

You can then tag and push this `hls-base` image as `<AWS_ACCOUNT_ID>.dkr.ecr.us-west-2.amazonaws.com/hls-base` and push it to ECR.

```shell
$ docker tag hls-base "${AWS_ACCOUNT_ID}.dkr.ecr.us-west-2.amazonaws.com/hls-base"
```

```shell
$ docker push "${AWS_ACCOUNT_ID}.dkr.ecr.us-west-2.amazonaws.com/hls-base"
```

