template <typename T>  __global__  void kernelgpuTdfunc(T *f, T *xdg, T *udg, T *odg, T *wdg, T *uinf, T *param, T time, int modelnumber, int ng, int nc, int ncu, int nd, int ncx, int nco, int ncw)
{
	int i = threadIdx.x + blockIdx.x * blockDim.x;
	while (i<ng) {
		f[0*ng+i] = 1.0;
		f[1*ng+i] = 1.0;
		f[2*ng+i] = 1.0;
		f[3*ng+i] = 1.0;
		i += blockDim.x * gridDim.x;
	}
}

template <typename T> void gpuTdfunc(T *f, T *xdg, T *udg, T *odg, T *wdg, T *uinf, T *param, T time, int modelnumber, int ng, int nc, int ncu, int nd, int ncx, int nco, int ncw)
{
	int blockDim = 256;
	int gridDim = (ng + blockDim - 1) / blockDim;
	gridDim = (gridDim>1024)? 1024 : gridDim;
	kernelgpuTdfunc<<<gridDim, blockDim>>>(f, xdg, udg, odg, wdg, uinf, param, time, modelnumber, ng, nc, ncu, nd, ncx, nco, ncw);
}

template void gpuTdfunc(double *, double *, double *, double *, double *, double *, double *, double, int, int, int, int, int, int, int, int);
template void gpuTdfunc(float *, float *, float *, float *, float *, float *, float *, float, int, int, int, int, int, int, int, int);
