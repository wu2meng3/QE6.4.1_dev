# make.inc.  Generated from make.inc.in by configure.

# compilation rules

.SUFFIXES :
.SUFFIXES : .o .c .f .f90

# most fortran compilers can directly preprocess c-like directives: use
# 	$(MPIF90) $(F90FLAGS) -c $<
# if explicit preprocessing by the C preprocessor is needed, use:
# 	$(CPP) $(CPPFLAGS) $< -o $*.F90
#	$(MPIF90) $(F90FLAGS) -c $*.F90 -o $*.o
# remember the tabulator in the first column !!!

.f90.o:
	$(MPIF90) $(F90FLAGS) -c $<

# .f.o and .c.o: do not modify

.f.o:
	$(F77) $(FFLAGS) -c $<

.c.o:
	$(CC) $(CFLAGS)  -c $<



# Top QE directory, useful for locating libraries,  linking QE with plugins
# The following syntax should always point to TOPDIR:
TOPDIR = $(dir $(abspath $(filter %make.inc,$(MAKEFILE_LIST))))
# if it doesn't work, uncomment the following line (edit if needed):

# TOPDIR = /global/homes/m/mwu/softwares/QE/QE6.5

# DFLAGS  = precompilation options (possible arguments to -D and -U)
#           used by the C compiler and preprocessor
# To use libxc (v>=3.0.1), add -D__LIBXC to DFLAGS
# See include/defs.h.README for a list of options and their meaning
# With the exception of IBM xlf, FDFLAGS = $(DFLAGS)
# For IBM xlf, FDFLAGS is the same as DFLAGS with separating commas

# MANUAL_DFLAGS  = additional precompilation option(s), if desired
#                  BEWARE: it does not work for IBM xlf! Manually edit FDFLAGS
MANUAL_DFLAGS  =
DFLAGS         =  -D__DFTI -D__MPI -D__OPENMP -D__SCALAPACK
FDFLAGS        = $(DFLAGS) $(MANUAL_DFLAGS)

# IFLAGS = how to locate directories with *.h or *.f90 file to be included
#          typically -I$(TOPDIR)/include -I/some/other/directory/
#          the latter contains .e.g. files needed by FFT libraries
# for libxc add -I/path/to/libxc/include/

MKLPATH      = $(MKLROOT)
HDF5PATH     = $(HDF5_DIR)

IFLAGS         = -I$(TOPDIR)/include -I$(TOPDIR)/FoX/finclude -I$(TOPDIR)/S3DE/iotk/include/ -I$(MKLPATH)/include -I$(HDF5PATH)/include -I${ELPA_DIR}/include/elpa_openmp-2017.05.001.rc1/modules -I${ELPA_DIR}/include/elpa_openmp-2017.05.001.rc1/elpa

# MOD_FLAG = flag used by f90 compiler to locate modules

MOD_FLAG      = -I

# BASEMOD_FLAGS points to directories containing basic modules,
# while BASEMODS points to the corresponding module libraries
# Each Makefile can add directories to MODFLAGS and libraries to QEMODS

BASEMOD_FLAGS= $(MOD_FLAG)$(TOPDIR)/iotk/src \
               $(MOD_FLAG)$(TOPDIR)/Modules \
               $(MOD_FLAG)$(TOPDIR)/FFTXlib \
	       $(MOD_FLAG)$(TOPDIR)/LAXlib \
	       $(MOD_FLAG)$(TOPDIR)/UtilXlib \
	       $(MOD_FLAG)$(TOPDIR)/FoX/finclude

# Compilers: fortran-90, fortran-77, C
# If a parallel compilation is desired, MPIF90 should be a fortran-90
# compiler that produces executables for parallel execution using MPI
# (such as for instance mpif90, mpf90, mpxlf90,...);
# otherwise, an ordinary fortran-90 compiler (f90, g95, xlf90, ifort,...)
# If you have a parallel machine but no suitable candidate for MPIF90,
# try to specify the directory containing "mpif.h" in IFLAGS
# and to specify the location of MPI libraries in MPI_LIBS

MPIF90         = ftn
F90            = ftn
CC             = cc
F77            = ftn

# GPU architecture (Kepler: 35, Pascal: 60, Volta: 70 )
GPU_ARCH=

# CUDA runtime (Pascal: 8.0, Volta: 9.0)
CUDA_RUNTIME=

# CUDA F90 Flags
CUDA_F90FLAGS=

# C preprocessor and preprocessing flags - for explicit preprocessing,
# if needed (see the compilation rules above)
# preprocessing flags must include DFLAGS and IFLAGS

CPP            = cpp
CPPFLAGS       = -P -traditional -Uvector $(DFLAGS) $(IFLAGS)

# compiler flags: C, F90, F77
# C flags must include DFLAGS and IFLAGS
# F90 flags must include MODFLAGS, IFLAGS, and FDFLAGS with appropriate syntax

CFLAGS         = -O3 $(DFLAGS) $(IFLAGS) -static -qopenmp -xCORE-AVX2
F90FLAGS       = $(FFLAGS) -nomodule -fpp $(FDFLAGS) $(CUDA_F90FLAGS) $(IFLAGS) $(MODFLAGS) -qopenmp
FFLAGS         = -O2 -assume byterecl -static -align array64byte -xCORE-AVX2 -qopenmp

# compiler flags without optimization for fortran-77
# the latter is NEEDED to properly compile dlamch.f, used by lapack

FFLAGS_NOOPT   = -O0 -assume byterecl

# compiler flag needed by some compilers when the main program is not fortran
# Currently used for Yambo

FFLAGS_NOMAIN   = -nofor_main

# Linker, linker-specific flags (if any)
# Typically LD coincides with F90 or MPIF90, LD_LIBS is empty
# for libxc, set LD_LIBS=-L/path/to/libxc/lib/ -lxcf90 -lxcf03 -lxc

LD             = ftn
LDFLAGS        = -static -qopenmp
LD_LIBS        = 

# External Libraries (if any) : blas, lapack, fft, MPI

# If you have nothing better, use the local copy via "--with-netlib" :
# BLAS_LIBS = /your/path/to/espresso/LAPACK/blas.a
# BLAS_LIBS_SWITCH = internal

BLAS_LIBS      =   -lmkl_intel_lp64  -lmkl_sequential -lmkl_core
BLAS_LIBS_SWITCH = external

# If you have nothing better, use the local copy via "--with-netlib" :
# LAPACK_LIBS = /your/path/to/espresso/LAPACK/lapack.a
# LAPACK_LIBS_SWITCH = internal
# For IBM machines with essl (-D__ESSL): load essl BEFORE lapack !
# remember that LAPACK_LIBS precedes BLAS_LIBS in loading order

LAPACK_LIBS    = 
LAPACK_LIBS_SWITCH = external

SCALAPACK_LIBS = $(MKLPATH)/lib/intel64/libmkl_scalapack_lp64.a -Wl,--start-group  $(MKLPATH)/lib/intel64/libmkl_intel_lp64.a $(MKLPATH)/lib/intel64/libmkl_intel_thread.a $(MKLPATH)/lib/intel64/libmkl_core.a $(MKLPATH)/lib/intel64/libmkl_blacs_intelmpi_lp64.a -Wl,--end-group

# nothing needed here if the the internal copy of FFTW is compiled
# (needs -D__FFTW in DFLAGS)

FFT_LIBS       = 

# HDF5
HDF5_LIBS = -L$(HDF5PATH)/lib -lhdf5hl_fortran -lhdf5_hl -lhdf5_fortran -lhdf5
FOX_LIB  = -L$(TOPDIR)/FoX/lib  -lFoX_dom -lFoX_sax -lFoX_wxml -lFoX_common\
            -lFoX_utils -lFoX_fsys 
FOX_FLAGS = 
# For parallel execution, the correct path to MPI libraries must
# be specified in MPI_LIBS (except for IBM if you use mpxlf)

MPI_LIBS       = 

# IBM-specific: MASS libraries, if available and if -D__MASS is defined in FDFLAGS

MASS_LIBS      = 

# CUDA libraries
CUDA_LIBS=
CUDA_EXTLIBS = 

# ar command and flags - for most architectures: AR = ar, ARFLAGS = ruv

AR             = ar
ARFLAGS        = ruv

# ranlib command. If ranlib is not needed (it isn't in most cases) use
# RANLIB = echo

RANLIB         = ranlib

# all internal and external libraries - do not modify

FLIB_TARGETS   = all

LIBOBJS        = $(TOPDIR)/clib/clib.a  $(TOPDIR)/iotk/src/libiotk.a
LIBXC_LIBS     = 
QELIBS         = $(CUDA_LIBS) $(SCALAPACK_LIBS) $(LAPACK_LIBS) $(FOX_LIB) $(FFT_LIBS) $(BLAS_LIBS) $(MPI_LIBS) $(MASS_LIBS) $(HDF5_LIBS) $(LIBXC_LIBS) $(LD_LIBS)

# wget or curl - useful to download from network
WGET = wget -O

# Install directory - "make install" copies *.x executables there
PREFIX = /usr/local
