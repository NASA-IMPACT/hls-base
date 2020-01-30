ARG AWS_ACCOUNT_ID
FROM ${AWS_ACCOUNT_ID}.dkr.ecr.us-west-2.amazonaws.com/espa/external:latest
ENV PREFIX=/usr/local \
    SRC_DIR=/usr/local/src \
    ESPAINC=/usr/local/include \
    ESPALIB=/usr/local/lib \
    L8_AUX_DIR=/usr/local/src \
    ECS_ENABLE_TASK_IAM_ROLE=true \
    PYTHONPATH="${PYTHONPATH}:${PREFIX}/lib/python2.7/site-packages" \
    LD_LIBRARY_PATH=/usr/local/MATLAB/v95/runtime/glnxa64:/usr/local/MATLAB/v95/bin/glnxa64:/usr/local/MATLAB/v95/sys/os/glnxa64A \
    XAPPLRESDIR=/usr/local/MATLAB/v95/X11/app-defaults

RUN pip install scipy gsutil awscli gdal~=2.4

RUN REPO_NAME=espa-product-formatter \
    && cd $SRC_DIR \
    && git clone https://github.com/NASA-IMPACT/${REPO_NAME}.git ${REPO_NAME} \
    && cd ${REPO_NAME} \
    && make BUILD_STATIC=yes ENABLE_THREADING=yes \
    && make install \
    && cd $SRC_DIR \
    && rm -rf ${REPO_NAME}

RUN REPO_NAME=espa-surface-reflectance \
    && cd $SRC_DIR \
    && git clone https://github.com/developmentseed/${REPO_NAME}.git \
    && cd ${REPO_NAME} \
    && make BUILD_STATIC=yes ENABLE_THREADING=yes \
    && make install \
    && make install-lasrc-aux \
    && cd $SRC_DIR \
    && rm -rf ${REPO_NAME}

RUN yum -y install java-1.8.0-openjdk-devel
COPY ./matlabenv /etc/environment

RUN pip install --upgrade git+https://github.com/USGS-EROS/espa-python-library.git@v1.1.0#espa

RUN cd ${SRC_DIR} \
  && wget --no-check-certificate --no-proxy 'http://fmask4installer.s3.amazonaws.com/Fmask_4_0.install' \
  && chmod +x Fmask_4_0.install \
  && ln -s /etc/ssl/certs/ca-bundle.trust.crt /etc/ssl/certs/ca-certificates.crt \
  && ./Fmask_4_0.install -destinationFolder /usr/local/MATLAB -agreeToLicense yes -mode silent \
  && rm Fmask_4_0.install

RUN yum -y install libXt

ENTRYPOINT ["/bin/sh", "-c"]
