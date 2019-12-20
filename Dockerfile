ARG AWS_ACCOUNT_ID
FROM ${AWS_ACCOUNT_ID}.dkr.ecr.us-west-2.amazonaws.com/espa/external:latest
ENV PREFIX=/usr/local \
    SRC_DIR=/usr/local/src \
    ESPAINC=/usr/local/include \
    ESPALIB=/usr/local/lib \
		L8_AUX_DIR=/usr/local/src \
    ECS_ENABLE_TASK_IAM_ROLE=true \
    PYTHONPATH="${PYTHONPATH}:${PREFIX}/lib/python2.7/site-packages"

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

RUN cd ${SRC_DIR} \
    && wget https://bitbucket.org/chchrsc/rios/downloads/rios-1.4.8.tar.gz \
    && tar xfv rios-1.4.8.tar.gz \
    && cd rios-1.4.8 \
    && python setup.py install --prefix=${PREFIX}

RUN cd ${SRC_DIR} \
    && wget https://bitbucket.org/chchrsc/python-fmask/downloads/python-fmask-0.5.4.tar.gz \
    && tar xfz python-fmask-0.5.4.tar.gz \
    && cd python-fmask-0.5.4 \
    && python setup.py build \
    && python setup.py install

COPY ./scripts "${SRC_DIR}/scripts"
RUN pip install "${SRC_DIR}/scripts/hlsfmask"

RUN pip install --upgrade git+https://github.com/USGS-EROS/espa-python-library.git@v1.1.0#espa

ENTRYPOINT ["/bin/sh", "-c"]

