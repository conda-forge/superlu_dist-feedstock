mkdir build
cd build

cmake .. ^
    -G Ninja ^
    %CMAKE_ARGS% ^
    -DCMAKE_INSTALL_INCLUDEDIR=include/superlu-dist ^
    -DCMAKE_BUILD_TYPE=RELEASE ^
    -Denable_openmp:BOOL=FALSE ^
    -DTPL_ENABLE_PARMETISLIB:BOOL=FALSE ^
    -DXSDK_ENABLE_Fortran=OFF ^
    -DTPL_ENABLE_LAPACKLIB=ON ^
    -DTPL_ENABLE_INTERNAL_BLASLIB=OFF ^
    -Denable_tests=ON ^
    -Denable_examples=OFF ^
    -Denable_python=OFF ^
    -Denable_doc=OFF ^
    -DBUILD_STATIC_LIBS=OFF ^
    -DBUILD_SHARED_LIBS=ON
if errorlevel 1 exit 1

cmake --build . --parallel %CPU_COUNT%
if errorlevel 1 exit 1

:: avoid heavy oversubscription of resources: already 1-2 MPI ranks (processes)
set OMP_NUM_THREADS=1
set KMP_NUM_THREADS=1
set MKL_NUM_THREADS=1
ctest --output-on-failure -R "(pdtest_1x1|pdtest_1x2|pdtest_2x1|pddrive)"
if errorlevel 1 exit 1

cmake --install .
if errorlevel 1 exit 1
