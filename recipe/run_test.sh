set -exuo pipefail

pushd EXAMPLE
mpicc $LDFLAGS $CFLAGS $(pkg-config --cflags --libs superlu_dist) pddrive.c dcreate_matrix.c -o pddrive
mpiexec -n 2 ./pddrive g20.rua
popd

pushd FORTRAN
mpifort $LDFLAGS $FFLAGS $(pkg-config --cflags superlu_dist) -lsuperlu_dist_fortran f_pddrive.F90 -o f_pddrive
mpiexec -n 4 ./f_pddrive ../EXAMPLE/g20.rua
popd
