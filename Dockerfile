# ARG AWS_ACCOUNT_ID
FROM 018923174646.dkr.ecr.us-west-2.amazonaws.com/espa/external:latest
ENV PREFIX=/usr/local \
    SRC_DIR=/usr/local/src \
    ESPAINC=/usr/local/include \
    ESPALIB=/usr/local/lib \
		L8_AUX_DIR=/usr/local/src \
    ECS_ENABLE_TASK_IAM_ROLE=true \
    PYTHONPATH="${PYTHONPATH}:${PREFIX}/lib/python2.7/site-packages"
    # XAPPLRESDIR=/usr/local/MATLAB/v95/X11/app-defaults

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

COPY ./matlabenv /etc/environment

RUN cd ${SRC_DIR} \
  && wget --no-check-certificate --no-proxy 'http://fmask4installer.s3.amazonaws.com/Fmask_4_0.install' \
  && chmod +x Fmask_4_0.install \
  && ln -s /etc/ssl/certs/ca-bundle.trust.crt /etc/ssl/certs/ca-certificates.crt \
  && ./Fmask_4_0.install -destinationFolder /usr/local/MATLAB -agreeToLicense yes -mode silent \
  && rm Fmask_4_0.install

RUN yum -y install libXt \
  && groupinstall -y "X Window System"

COPY ./scripts "${SRC_DIR}/scripts"
COPY ./download.sh "${PREFIX}"
# RUN pip install "${SRC_DIR}/scripts/hlsfmask"

# RUN pip install --upgrade git+https://github.com/USGS-EROS/espa-python-library.git@v1.1.0#espa

ENTRYPOINT ["/bin/sh", "-c"]

