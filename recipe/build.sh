#!/usr/bin/env bash

export CFLAGS="$CFLAGS -std=c99 -fPIC"

if [ "${mpi}" == "openmpi" ]; then
    export OMPI_MCA_plm=isolated
    export OMPI_MCA_btl_vader_single_copy_mechanism=none
    export OMPI_MCA_rmaps_base_oversubscribe=yes
fi

WORK=$PWD
# run full build & install twice, once for static, once for shared
# because it's the cmake way
for shared in OFF ON; do
    cd "$WORK"
    mkdir build_$shared
    cd build_$shared
    # enable_blaslib=OFF so OpenBLAS will be found instead of the built-in BLAS

    # build & install once for static
    cmake .. \
        -DCMAKE_INSTALL_PREFIX="${PREFIX}" \
        -DCMAKE_INSTALL_LIBDIR="${PREFIX}/lib" \
        -DCMAKE_C_FLAGS="${CFLAGS}" \
        -DCMAKE_C_COMPILER=mpicc \
        -DCMAKE_CXX_COMPILER=mpic++ \
        -DCMAKE_BUILD_TYPE=RELEASE \
        -DTPL_PARMETIS_INCLUDE_DIRS="${PREFIX}/include" \
        -DTPL_PARMETIS_LIBRARIES="${PREFIX}/lib/libparmetis${SHLIB_EXT};${PREFIX}/lib/libmetis${SHLIB_EXT}" \
        -DTPL_BLAS_LIBRARIES="${PREFIX}/lib/libblas${SHLIB_EXT}" \
        -DTPL_LAPACK_LIBRARIES="${PREFIX}/lib/liblapack${SHLIB_EXT};${PREFIX}/lib/libblas${SHLIB_EXT}" \
        -Denable_blaslib=OFF \
        -Denable_tests=ON \
        -Denable_doc=OFF \
        -DBUILD_SHARED_LIBS=$shared

    make -j${CPU_COUNT}

    # ctest seems to have weird PATH assumptions
    export PATH=$PWD/EXAMPLE:$PWD/TEST:$PATH
    # avoid heavy oversubscription of resources: already 1-2 MPI ranks (processes)
    export OMP_NUM_THREADS=1
    export KMP_NUM_THREADS=${OMP_NUM_THREADS}
    export MKL_NUM_THREADS=${OMP_NUM_THREADS}
    export CTEST_REGEX="-R (pdtest_1x1|pdtest_1x2|pdtest_2x1|pddrive)"
if [[ "${CONDA_BUILD_CROSS_COMPILATION:-}" != "1" ]]; then
    ctest ${CTEST_REGEX}
fi

    make install
done
