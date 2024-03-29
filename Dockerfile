FROM 018923174646.dkr.ecr.us-west-2.amazonaws.com/espa/external-c2:latest
ARG lasrc_version
ENV PREFIX=/usr/local \
    SRC_DIR=/usr/local/src \
    ESPAINC=/usr/local/include \
    ESPALIB=/usr/local/lib \
    ECS_ENABLE_TASK_IAM_ROLE=true \
    PYTHONPATH="${PYTHONPATH}:${PREFIX}/lib/python3.6/site-packages" \
    ESPA_SCHEMA="${PREFIX}/schema/espa_internal_metadata_v2_2.xsd" \
    FMASK_VERSION="4_6"

RUN pip3 install scipy gsutil awscli gdal~=2.4
RUN yum -y install java-1.8.0-openjdk-devel
COPY ./matlabenv /etc/environment
RUN cd ${SRC_DIR} \
  && wget -q --no-check-certificate --no-proxy "http://fmask4installer.s3.amazonaws.com/Fmask_${FMASK_VERSION}_Linux_mcr.install" \
  && chmod +x "Fmask_${FMASK_VERSION}_Linux_mcr.install" \
  && ln -s /etc/ssl/certs/ca-bundle.trust.crt /etc/ssl/certs/ca-certificates.crt \
  && "./Fmask_${FMASK_VERSION}_Linux_mcr.install" -destinationFolder /usr/local/MATLAB -agreeToLicense yes -mode silent \
  && rm "Fmask_${FMASK_VERSION}_Linux_mcr.install"
RUN yum -y install libXt
COPY ./run_Fmask.sh /usr/bin

RUN REPO_NAME=espa-product-formatter \
    && cd $SRC_DIR \
    && git clone -b 3.5.0 https://github.com/NASA-IMPACT/${REPO_NAME}.git ${REPO_NAME} \
    && cd ${REPO_NAME} \
    && make BUILD_STATIC=yes \
    && make install \
    && cd $SRC_DIR \
    && rm -rf ${REPO_NAME}
RUN REPO_NAME=espa-surface-reflectance \
    && cd $SRC_DIR \
    && git clone -b "eros-collection2-${lasrc_version}" https://github.com/NASA-IMPACT/${REPO_NAME}.git \
    && cd ${REPO_NAME} \
    && make ENABLE_THREADING=yes \
    && make install \
    && make install-lasrc-aux \
    && cd $SRC_DIR \
    && rm -rf ${REPO_NAME}

RUN ln -fs /usr/bin/python3 /usr/bin/python
RUN pip3 install --upgrade git+https://github.com/repository-preservation/espa-python-library@v2.0.0#espa

ENTRYPOINT ["/bin/sh", "-c"]
