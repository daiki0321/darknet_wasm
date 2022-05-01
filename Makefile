GPU=0
CUDNN=0
OPENCV=0
OPENMP=0
DEBUG=0

ARCH= -gencode arch=compute_30,code=sm_30 \
      -gencode arch=compute_35,code=sm_35 \
      -gencode arch=compute_50,code=[sm_50,compute_50] \
      -gencode arch=compute_52,code=[sm_52,compute_52]
#      -gencode arch=compute_20,code=[sm_20,sm_21] \ This one is deprecated?

# This is what I use, uncomment if you know your arch and want to specify
# ARCH= -gencode arch=compute_52,code=compute_52

VPATH=./src/:./examples
SLIB=libdarknet.so
ALIB=libdarknet.a
#EXEC=darknet
EXEC=darknet.wasm
OBJDIR=./obj/

WASI_SDK_PATH = /opt/wasi-sdk-14.0

CC=$(WASI_SDK_PATH)/bin/clang --sysroot=$(WASI_SDK_PATH)/share/wasi-sysroot
CPP=$(WASI_SDK_PATH)/bin/clang++ --sysroot=$(WASI_SDK_PATH)/share/wasi-sysroot
NVCC=nvcc 
#AR=ar
AR=$(WASI_SDK_PATH)/bin/ar
ARFLAGS=rcs
OPTS=-Ofast
LDFLAGS= -lm -pthread 
COMMON= -Iinclude/ -Isrc/
#CFLAGS=-Wall -Wno-unused-result -Wno-unknown-pragmas -Wfatal-errors -fPIC
CFLAGS=-pthread -Ofast -Wall -Wextra -Wformat -Wformat-security

CFLAGS += -I$(WASI_SDK_PATH)/share/wasi-sysroot/include

ifeq ($(OPENMP), 1) 
CFLAGS+= -fopenmp
endif

ifeq ($(DEBUG), 1) 
OPTS=-O0 -g
endif

CFLAGS+=$(OPTS)

ifeq ($(OPENCV), 1) 
COMMON+= -DOPENCV
CFLAGS+= -DOPENCV
LDFLAGS+= `pkg-config --libs opencv` -lstdc++
COMMON+= `pkg-config --cflags opencv` 
endif

ifeq ($(GPU), 1) 
COMMON+= -DGPU -I/usr/local/cuda/include/
CFLAGS+= -DGPU
LDFLAGS+= -L/usr/local/cuda/lib64 -lcuda -lcudart -lcublas -lcurand
endif

ifeq ($(CUDNN), 1) 
COMMON+= -DCUDNN 
CFLAGS+= -DCUDNN
LDFLAGS+= -lcudnn
endif

OBJ=gemm.o utils.o cuda.o deconvolutional_layer.o convolutional_layer.o list.o image.o activations.o im2col.o col2im.o blas.o crop_layer.o dropout_layer.o maxpool_layer.o softmax_layer.o data.o matrix.o network.o connected_layer.o cost_layer.o parser.o option_list.o detection_layer.o route_layer.o upsample_layer.o box.o normalization_layer.o avgpool_layer.o layer.o local_layer.o shortcut_layer.o logistic_layer.o activation_layer.o rnn_layer.o gru_layer.o crnn_layer.o demo.o batchnorm_layer.o region_layer.o reorg_layer.o tree.o  lstm_layer.o l2norm_layer.o yolo_layer.o iseg_layer.o image_opencv.o
#EXECOBJA=captcha.o lsd.o super.o art.o tag.o cifar.o go.o rnn.o segmenter.o regressor.o classifier.o coco.o yolo.o detector.o nightmare.o instance-segmenter.o darknet.o
EXECOBJA=yolo.o detector.o darknet.o

ifeq ($(GPU), 1) 
LDFLAGS+= -lstdc++ 
OBJ+=convolutional_kernels.o deconvolutional_kernels.o activation_kernels.o im2col_kernels.o col2im_kernels.o blas_kernels.o crop_layer_kernels.o dropout_layer_kernels.o maxpool_layer_kernels.o avgpool_layer_kernels.o
endif

EXECOBJ = $(addprefix $(OBJDIR), $(EXECOBJA))
OBJS = $(addprefix $(OBJDIR), $(OBJ))
DEPS = $(wildcard src/*.h) Makefile include/darknet.h

LDFLAGS += -Wl,--strip-all \
            -Wl,--no-entry \
	    -Wl,--initial-memory=6553600 \
            -Wl,--max-memory=536870912 \
	    -z stack-size=655360 \
	    -Wl,--shared-memory,--no-check-features \
	    -Wl,--allow-undefined      \
	    -Wl,--export=__heap_base,--export=__data_end

all: obj backup results $(ALIB) $(EXEC)
#all: obj  results $(SLIB) $(ALIB) $(EXEC)


$(EXEC): $(OBJS) $(EXECOBJ)
	$(CC) $(LDFLAGS) $^ -o $@

$(ALIB): $(OBJS)
	$(AR) $(ARFLAGS) $@ $^

$(SLIB): $(OBJS)
	$(CC) $(CFLAGS) -shared $^ -o $@ $(LDFLAGS)

$(OBJDIR)%.o: %.cpp $(DEPS)
	$(CPP) $(COMMON) $(CFLAGS) -c $< -o $@

$(OBJDIR)%.o: %.c $(DEPS)
	$(CC) $(COMMON) $(CFLAGS) -c $< -o $@

$(OBJDIR)%.o: %.cu $(DEPS)
	$(NVCC) $(ARCH) $(COMMON) --compiler-options "$(CFLAGS)" -c $< -o $@

obj:
	mkdir -p obj
backup:
	mkdir -p backup
results:
	mkdir -p results

.PHONY: clean

clean:
	rm -rf $(OBJS) $(SLIB) $(ALIB) $(EXEC) $(EXECOBJ) $(OBJDIR)/*

