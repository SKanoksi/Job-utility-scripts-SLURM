/*************************************************
 *
 * Check GPU Binding (check_gpu.c)
 *
 * = Simple c program for checking resource binding:
 *   - CUDA devices,
 *   - OpenMP threads
 *   bound to each MPI process.
 *
 * Copyright (c) 2024, Somrath Kanoksirirath.
 * All rights reserved under BSD 3-clause license.
 *
 *************************************************/

#include <stdio.h>
#include <mpi.h>
#include <omp.h>
#include <nvml.h>
#include <cuda_runtime_api.h>

int main(int argc, char **argv) {

  int rank, size, num_thread ;
  MPI_Init(NULL, NULL);
  MPI_Comm_rank(MPI_COMM_WORLD, &rank);
  MPI_Comm_size(MPI_COMM_WORLD, &size);
  #pragma omp parallel
  {
    num_thread = omp_get_num_threads();
  }

  nvmlReturn_t return_code ;
  int error_code ;
  int deviceCount = 0;

  return_code = nvmlInit();
  if( return_code != NVML_SUCCESS ){
    printf("Return %d from nvmlInit\n", return_code);
    MPI_Abort(MPI_COMM_WORLD, 1);
  }

  error_code = cudaGetDeviceCount(&deviceCount);
  if( error_code != cudaSuccess ){
    printf("Return %d from cudaGetDeviceCount\n", error_code);
    MPI_Abort(MPI_COMM_WORLD, 1);
  }


  for(int i=0 ; i<deviceCount ; ++i)
  {
    struct cudaDeviceProp prop ;
    nvmlDevice_t device ;
    char busId[NVML_DEVICE_PCI_BUS_ID_BUFFER_SIZE];
    char uuid[NVML_DEVICE_UUID_BUFFER_SIZE];

    error_code = cudaGetDeviceProperties(&prop, i);
    if( error_code != cudaSuccess ){
      printf("Return %d from cudaGetDevicePropertiesCount of device %d\n", error_code, i);
      MPI_Abort(MPI_COMM_WORLD, 1);
    }

    sprintf(busId, NVML_DEVICE_PCI_BUS_ID_FMT, prop.pciDomainID, prop.pciBusID, prop.pciDeviceID);
    nvmlDeviceGetHandleByPciBusId(busId, &device);
    if( return_code != NVML_SUCCESS ){
      printf("Return %d from nvmlDeviceGetHandleByPciBusId\n", return_code);
      MPI_Abort(MPI_COMM_WORLD, 1);
    }

    return_code = nvmlDeviceGetUUID(device, uuid, NVML_DEVICE_UUID_BUFFER_SIZE);
    if( return_code != NVML_SUCCESS ){
      printf("Return %d from nvmlDeviceGetUUID\n", return_code);
      MPI_Abort(MPI_COMM_WORLD, 1);
    }

    printf("Task %2d from totally %2d with %2d threads detects %s (%2d/%2d) [%s]\n", rank, size, num_thread, prop.name, i+1, deviceCount, uuid);

  }


  MPI_Finalize();

return 0; }



