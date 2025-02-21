#include <iostream>
#include <mpi.h>
#include <omp.h>
#include <unistd.h>
#include <limits.h>


int main(){
    int rank, thread ;
    omp_lock_t io_lock ;
    omp_init_lock(&io_lock);

    MPI_Init(nullptr,nullptr);
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
   
    char hostname[HOST_NAME_MAX];
    gethostname(hostname, sizeof(hostname));

    #pragma omp parallel private(thread)
    {
        thread = omp_get_thread_num();
        omp_set_lock(&io_lock);
        std::cout 
	<< "HelloWorld from rank " << rank 
	<< " thread " << thread 
	<< " (" << hostname << ")"
	<< std::endl;
        omp_unset_lock(&io_lock);
    }

    omp_destroy_lock(&io_lock);
    MPI_Finalize();
    
return 0; }
