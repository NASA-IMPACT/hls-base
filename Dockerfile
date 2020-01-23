# ARG AWS_ACCOUNT_ID
FROM 018923174646.dkr.ecr.us-west-2.amazonaws.com/espa/external:latest
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

# RUN cd ${SRC_DIR} \
    # && wget https://bitbucket.org/chchrsc/rios/downloads/rios-1.4.8.tar.gz \
    # && tar xfv rios-1.4.8.tar.gz \
    # && cd rios-1.4.8 \
    # && python setup.py install --prefix=${PREFIX}

# RUN cd ${SRC_DIR} \
    # && wget https://bitbucket.org/chchrsc/python-fmask/downloads/python-fmask-0.5.4.tar.gz \
    # && tar xfz python-fmask-0.5.4.tar.gz \
    # && cd python-fmask-0.5.4 \
    # && python setup.py build \
    # && python setup.py install
    
# Install the MCR dependencies and some things we'll need and download the MCR
# from Mathworks -silently install it
RUN mkdir /mcr-install && \
    mkdir /usr/local/MATLAB && \
    cd /mcr-install && \
    wget -q  https://ssd.mathworks.com/supportfiles/downloads/R2018b/deployment_files/R2018b/installers/glnxa64/MCR_R2018b_glnxa64_installer.zip && \
    unzip -q MCR_R2018b_glnxa64_installer.zip  && \
    rm -f MCR_R2018b_glnxa64_installer.zip  && \
    ./install -destinationFolder /usr/local/MATLAB -agreeToLicense yes -mode silent && \
    cd / && \
    rm -rf mcr-install

RUN cd ${SRC_DIR} \
  && wget --no-check-certificate --no-proxy
  'http://fmask4installer.s3.amazonaws.com/Fmask_4_0.install' \
  && chmod +x Fmask_4_0.install \
  && ./Fmask_4_0.install \
  && rm Fmask_4_0.install

COPY ./scripts "${SRC_DIR}/scripts"
RUN pip install "${SRC_DIR}/scripts/hlsfmask"

# RUN pip install --upgrade git+https://github.com/USGS-EROS/espa-python-library.git@v1.1.0#espa

ENTRYPOINT ["/bin/sh", "-c"]

