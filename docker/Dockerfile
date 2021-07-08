FROM nvcr.io/nvidia/l4t-pytorch:r32.5.0-pth1.7-py3
RUN apt-get update -y
RUN apt-get install python3-pip libopenblas-base libopenmpi-dev -y
RUN DEBIAN_FRONTEND=noninteractive apt-get install libhdf5-serial-dev hdf5-tools libhdf5-dev zlib1g-dev zip libjpeg8-dev liblapack-dev libblas-dev gfortran -y
RUN DEBIAN_FRONTEND=noninteractive apt-get install python3 python-dev python3-dev build-essential libssl-dev libffi-dev libxml2-dev libxslt1-dev zlib1g-dev python-pip cmake openssh-client openssh-server -yq
RUN pip3 install -U Cython
RUN pip3 install -U testresources setuptools
RUN pip3 install horovod --no-cache-dir