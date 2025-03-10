template <typename T>  __global__  void kernelgpuFlux(T *f, T *xdg, T *udg, T *odg, T *wdg, T *uinf, T *param, T time, int modelnumber, int ng, int nc, int ncu, int nd, int ncx, int nco, int ncw)
{
	int i = threadIdx.x + blockIdx.x * blockDim.x;
	while (i<ng) {
		T param1 = param[0];
		T param2 = param[1];
		T param3 = param[2];
		T param7 = param[6];
		T udg1 = udg[0*ng+i];
		T udg2 = udg[1*ng+i];
		T udg3 = udg[2*ng+i];
		T udg4 = udg[3*ng+i];
		T udg5 = udg[4*ng+i];
		T udg6 = udg[5*ng+i];
		T udg7 = udg[6*ng+i];
		T udg8 = udg[7*ng+i];
		T udg9 = udg[8*ng+i];
		T udg10 = udg[9*ng+i];
		T udg11 = udg[10*ng+i];
		T udg12 = udg[11*ng+i];
		T t2 = udg2*udg2;
		T t3 = 1.0/(udg1*udg1);
		T t4 = 1.0/udg1;
		T t5 = t2*t3*(1.0/2.0);
		T t6 = udg3*udg3;
		T t7 = t3*t6*(1.0/2.0);
		T t8 = t5+t7;
		T t11 = t8*udg1;
		T t9 = -t11+udg4;
		T t10 = param1-1.0;
		T t12 = 1.0/param1;
		T t22 = param7*t12;
		T t13 = param7-t22;
		T t14 = 1.0/(t13*t13);
		T t15 = t4*t9*t10*t14;
		T t16 = sqrt(t15);
		T t28 = t4*udg3*udg5;
		T t17 = -t28+udg7;
		T t18 = t4*t17;
		T t31 = t4*udg2*udg9;
		T t19 = -t31+udg10;
		T t20 = t4*t19;
		T t21 = t18+t20;
		T t27 = t4*udg2*udg5;
		T t23 = -t27+udg6;
		T t24 = t4*t23*2.0;
		T t35 = t4*udg3*udg9;
		T t25 = -t35+udg11;
		T t26 = t24-t4*t25;
		T t29 = 1.0/t13;
		T t30 = t4*udg2*udg3;
		T t32 = param2*t16*t21;
		T t33 = t30+t32;
		T t34 = t9*t10;
		T t36 = t4*udg4;
		T t37 = t4*t9*t10;
		T t38 = t36+t37;
		T t39 = t4*t23;
		T t40 = t39-t4*t25*2.0;
		T t41 = t4*t9*t10*t29;
		T t42 = pow(t41,3.0/4.0);
		f[0*ng+i] = udg2;
		f[1*ng+i] = t34+t2*t4+param2*t16*t26*(2.0/3.0);
		f[2*ng+i] = t33;
		f[3*ng+i] = t38*udg2+param2*t4*t16*t21*udg3+param2*t4*t16*t26*udg2*(2.0/3.0)-param3*t3*t29*t42*(t10*udg1*(-udg8+t8*udg5+udg1*(t3*t17*udg3+t3*t23*udg2))+t9*t10*udg5);
		f[4*ng+i] = udg3;
		f[5*ng+i] = t33;
		f[6*ng+i] = t34+t4*t6-param2*t16*t40*(2.0/3.0);
		f[7*ng+i] = t38*udg3+param2*t4*t16*t21*udg2-param2*t4*t16*t40*udg3*(2.0/3.0)-param3*t3*t29*t42*(t10*udg1*(-udg12+t8*udg9+udg1*(t3*t19*udg2+t3*t25*udg3))+t9*t10*udg9);
		i += blockDim.x * gridDim.x;
	}
}

template <typename T> void gpuFlux(T *f, T *xdg, T *udg, T *odg, T *wdg, T *uinf, T *param, T time, int modelnumber, int ng, int nc, int ncu, int nd, int ncx, int nco, int ncw)
{
	int blockDim = 256;
	int gridDim = (ng + blockDim - 1) / blockDim;
	gridDim = (gridDim>1024)? 1024 : gridDim;
	kernelgpuFlux<<<gridDim, blockDim>>>(f, xdg, udg, odg, wdg, uinf, param, time, modelnumber, ng, nc, ncu, nd, ncx, nco, ncw);
}

template void gpuFlux(double *, double *, double *, double *, double *, double *, double *, double, int, int, int, int, int, int, int, int);
template void gpuFlux(float *, float *, float *, float *, float *, float *, float *, float, int, int, int, int, int, int, int, int);
