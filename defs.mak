# defs.mak.in --
# source file for autoconf-generated "defs.mak" for magic

# defs.mak.  Generated from defs.mak.in by configure.
# Feel free to change the values in here to suit your needs.
# Be aware that running scripts/configure again will overwrite
# any changes!

SHELL                  = /bin/sh

prefix = /usr/local
exec_prefix = ${prefix}
bindir = ${exec_prefix}/bin
libdir = ${exec_prefix}/lib
mandir = ${prefix}/share/man

SCRIPTS		       = ${MAGICDIR}/scripts

INSTALL = /bin/install -c
INSTALL_PROGRAM = ${INSTALL}
INSTALL_DATA = ${INSTALL} -m 644
INSTALL_SCRIPT = ${INSTALL}

# Override standard "make" target when compiling under TCL
ALL_TARGET = standard
INSTALL_TARGET = install-magic

# Change libdir to install in a different place
BINDIR                 = ${bindir}
MANDIR                 = ${mandir}
LIBDIR                 = ${libdir}
SYSDIR                 = ${libdir}/magic/sys
SCMDIR                 = ${libdir}/magic/scm
TCLDIR                 = ${libdir}/magic/tcl

MAIN_EXTRA_LIBS	       =  ${MAGICDIR}/calma/libcalma.o ${MAGICDIR}/cif/libcif.o ${MAGICDIR}/plot/libplot.o ${MAGICDIR}/lef/liblef.o ${MAGICDIR}/extflat/libextflat.o ${MAGICDIR}/garouter/libgarouter.o 	${MAGICDIR}/mzrouter/libmzrouter.o ${MAGICDIR}/router/librouter.o 	${MAGICDIR}/irouter/libirouter.o ${MAGICDIR}/grouter/libgrouter.o 	${MAGICDIR}/gcr/libgcr.o
LD_EXTRA_LIBS	       = 
LD_SHARED	       = 
TOP_EXTRA_LIBS	       = 
SUB_EXTRA_LIBS	       = 

MODULES               +=  calma cif plot lef readline garouter grouter irouter mzrouter router gcr
UNUSED_MODULES        +=  lisp tcltk
PROGRAMS	      +=  ext2sim ext2spice net2ir extcheck graphics
INSTALL_CAD_DIRS      += 

RM                     = rm -f
CP                     = cp
AR                     = ar
ARFLAGS                = crv
LINK                   = ld -r
LD                     = /bin/ld
M4		       = /bin/m4
RANLIB                 = ranlib
SHDLIB_EXT             = 
LDDL_FLAGS             = ${LDFLAGS} 
LD_RUN_PATH	       = 
LIB_SPECS	       = 
WISH_EXE	       = 
TCL_LIB_DIR	       = 
MAGIC_VERSION	       = 8.1
MAGIC_REVISION	       = 98

CC                     = gcc
CPP                    = gcc -E -x c
CXX		       = g++

CPPFLAGS               = -I. -I${MAGICDIR} 
DFLAGS                 =  -DCAD_DIR=\"${LIBDIR}\" -DBIN_DIR=\"${BINDIR}\" -DPACKAGE_NAME=\"\" -DPACKAGE_TARNAME=\"\" -DPACKAGE_VERSION=\"\" -DPACKAGE_STRING=\"\" -DPACKAGE_BUGREPORT=\"\" -DPACKAGE_URL=\"\" -DMAGIC_VERSION=\"8.1\" -DMAGIC_REVISION=\"98\" -DSTDC_HEADERS=1 -DHAVE_SYS_TYPES_H=1 -DHAVE_SYS_STAT_H=1 -DHAVE_STDLIB_H=1 -DHAVE_STRING_H=1 -DHAVE_MEMORY_H=1 -DHAVE_STRINGS_H=1 -DHAVE_INTTYPES_H=1 -DHAVE_STDINT_H=1 -DHAVE_UNISTD_H=1 -DSIZEOF_VOID_P=8 -DSIZEOF_UNSIGNED_INT=4 -DSIZEOF_UNSIGNED_LONG=8 -DSIZEOF_UNSIGNED_LONG_LONG=8 -DSTDC_HEADERS=1 -DHAVE_SETENV=1 -DHAVE_PUTENV=1 -DHAVE_SYS_MMAN_H=1 -DHAVE_DIRENT_H=1 -DHAVE_LIMITS_H=1 -DHAVE_PATHS_H=1 -DHAVE_VA_COPY=1 -DHAVE___VA_COPY=1 -DEXT2SPICE_AUTO=1 -DEXT2SIM_AUTO=1 -DFILE_LOCKS=1 -DCALMA_MODULE=1 -DCIF_MODULE=1 -DX11_BACKING_STORE=1 -DPLOT_MODULE=1 -DLEF_MODULE=1 -DUSE_READLINE=1 -DHAVE_LIBREADLINE=1 -DHAVE_LIBREADLINE=1 -DHAVE_LIBREADLINE=1 -DHAVE_LIBREADLINE=1 -DHAVE_READLINE=1 -DHAVE_PTHREADS=1 -DROUTE_MODULE=1 -DRSIM_MODULE=1 -DUSE_NEW_MACROS=1 -DHAVE_LIBGL=1 -DHAVE_LIBGLU=1 -DVECTOR_FONTS=1 -Dlinux=1 -DSYSV=1 -DISC=1 -DNDEBUG -DGCORE=\"/bin/gcore\"
DFLAGS		      += -DSHDLIB_EXT=\"\"
CFLAGS                 = -g -m64 -fPIC  

READLINE_DEFS          = 
READLINE_LIBS          = -lreadline -ltermcap

DEPEND_FILE	       = Depend
DEPEND_FLAG	       = -MM
EXEEXT		       = 

GR_CFLAGS              =  
GR_DFLAGS	       =  -DX11 -DXLIB -DOGL -DNDEBUG
GR_LIBS                =  -lpthread -lX11 -lGL -lGLU -lXi -lXmu -lXext -lm -lstdc++ ${X11_LDFLAGS} 
GR_SRCS                =  ${X11THREAD_SRCS} ${X11_SRCS} ${OGL_SRCS}
GR_HELPER_SRCS         = 
GR_HELPER_PROG         = 

OA		       = 
OA_LIBS		       = 

DEPSRCS	  = ${SRCS}
OBJS      = ${SRCS:.c=.o} ${CXXSRCS:.cpp=.o}
LIB_OBJS  = ${LIB_SRCS:.c=.o}
CLEANS    = ${OBJS} ${LIB_OBJS} lib${MODULE}.a lib${MODULE}.o ${MODULE}
