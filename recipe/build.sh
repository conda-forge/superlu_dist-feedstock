#!/usr/bin/env bash

set -ex
export CFLAGS="$CFLAGS -std=c99 -fPIC"

if [ "${mpi}" == "openmpi" ]; then
    export OPAL_PREFIX=$PREFIX
    export OMPI_MCA_pml=ob1
    export OMPI_MCA_btl=sm,self
    export OMPI_MCA_plm_ssh_agent=false
    export OMPI_MCA_rmaps_default_mapping_policy=:oversubscribe
fi

if [[ "${CONDA_BUILD_CROSS_COMPILATION:-}" != "1" ]]; then
    WITH_TESTS=ON
else
    WITH_TESTS=OFF
fi

# workaround until https://github.com/conda-forge/clang-compiler-activation-feedstock/pull/70 is merged
CMAKE_ARGS="${CMAKE_ARGS} -DCMAKE_PROGRAM_PATH=${BUILD_PREFIX}/bin;$PREFIX/bin"

if [[ $target_platform =~ osx* && $mpi = "mpich" ]]; then
  # figure out how to remove -fallow-argument-mismatch
  # which is passed to C, but is fortran-only
  ENABLE_FORTRAN=OFF
else
  ENABLE_FORTRAN=ON
fi

WORK=$PWD

mkdir build
cd build

# build & install once for static
cmake .. \
    ${CMAKE_ARGS} \
    -DCMAKE_C_FLAGS="${CFLAGS}" \
    -DCMAKE_C_COMPILER="${CC}" \
    -DCMAKE_CXX_COMPILER="${CXX}" \
    -DCMAKE_Fortran_COMPILER="${FC}" \
    -DCMAKE_Fortran_FLAGS="${FFLAGS}" \
    -DCMAKE_INSTALL_INCLUDEDIR=include/superlu-dist \
    -DCMAKE_BUILD_TYPE=RELEASE \
    -DTPL_ENABLE_PARMETISLIB=ON \
    -DTPL_PARMETIS_INCLUDE_DIRS="${PREFIX}/include" \
    -DTPL_PARMETIS_LIBRARIES="${PREFIX}/lib/libparmetis${SHLIB_EXT};${PREFIX}/lib/libmetis${SHLIB_EXT}" \
    -DTPL_BLAS_LIBRARIES="${PREFIX}/lib/libblas${SHLIB_EXT}" \
    -DTPL_ENABLE_LAPACKLIB=ON \
    -DTPL_LAPACK_LIBRARIES="${PREFIX}/lib/liblapack${SHLIB_EXT};${PREFIX}/lib/libblas${SHLIB_EXT}" \
    -DTPL_ENABLE_INTERNAL_BLASLIB=OFF \
    -DXSDK_ENABLE_Fortran=${ENABLE_FORTRAN} \
    -Denable_tests=${WITH_TESTS} \
    -Denable_doc=OFF \
    -DBUILD_STATIC_LIBS=OFF \
    -DBUILD_SHARED_LIBS=ON

cmake --build .

# ctest seems to have weird PATH assumptions
export PATH=$PWD/EXAMPLE:$PWD/TEST:$PATH
# avoid heavy oversubscription of resources: already 1-2 MPI ranks (processes)
export OMP_NUM_THREADS=1
export KMP_NUM_THREADS=${OMP_NUM_THREADS}
export MKL_NUM_THREADS=${OMP_NUM_THREADS}
export CTEST_REGEX="-R (pdtest_1x1|pdtest_1x2|pdtest_2x1|pddrive)"
if [[ "${CONDA_BUILD_CROSS_COMPILATION:-}" != "1" || "${CROSSCOMPILING_EMULATOR}" != "" ]]; then
    ctest --output-on-failure ${CTEST_REGEX}
fi

cmake --install .
