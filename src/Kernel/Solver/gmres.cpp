#ifndef __GMRESSOLVER
#define __GMRESSOLVER 
void MGS(cublasHandle_t handle, dstype *V, dstype *H, Int N, Int m, Int backend)
{
    for (Int k = 0; k < m; k++) {
        PDOT(handle, N, &V[m*N], inc1, &V[k*N], inc1, &H[k], backend);
        ArrayAXPBY(&V[m*N], &V[m*N], &V[k*N], one, -H[k], N, backend);
    }
    PDOT(handle, N, &V[m*N], inc1, &V[m*N], inc1, &H[m], backend);
    H[m] = sqrt(H[m]);    
    ArrayMultiplyScalar(&V[m*N], one/H[m], N, backend);
}
void CGS(cublasHandle_t handle, dstype *V, dstype *H, dstype *temp, Int N, Int m, Int backend)
{
    PGEMTV(handle, N, m, &one, V, N, &V[m*N], inc1, &zero, H, inc1, temp, backend);
    PGEMNV(handle, N, m, &minusone, V, N, H, inc1, &one, &V[m*N], inc1, backend);
    PDOT(handle, N, &V[m*N], inc1, &V[m*N], inc1, &H[m], backend);
    H[m] = sqrt(H[m]);
    ArrayMultiplyScalar(&V[m*N], one/H[m], N, backend);
}

void ApplyPoly(dstype *w, CDiscretization &disc, sysstruct &sys, dstype *q, dstype *p, int N, int backend)
{
    int m = disc.common.ppdegree;
    dstype *sr = &sys.lam[2*m];
    dstype *si = &sys.lam[3*m];    

    ArrayCopy(q, w, N, backend);
    ArraySetValue(w, 0.0, N, backend);
    
    dstype a, b, a2b2;
    int i = 0;
    
    while (i<(m-1)) {
        if (si[i] == 0) {
           ArrayAXPBY(w, w, q, 1.0, 1.0/sr[i], N, backend);        
           disc.evalMatVec(p, q, sys.u, sys.b, backend);      
           ArrayAXPBY(q, q, p, 1.0, -1.0/sr[i], N, backend);                   
           i = i + 1;            
        }        
        else {
            a = sr[i];
            b = si[i];
            a2b2 = a*a + b*b;
            disc.evalMatVec(p, q, sys.u, sys.b, backend);      
            ArrayAXPBY(p, q, p, 2*a, -1.0, N, backend);      
            ArrayAXPBY(w, w, p, 1.0, 1.0/a2b2, N, backend);                
           if ( i < (m - 2) ) {
               disc.evalMatVec(p, p, sys.u, sys.b, backend);      
               ArrayAXPBY(q, q, p, 1.0, -1.0/a2b2, N, backend);   
           }
           i += 2; 
        }
    }
    if (si[m-1] == 0) 
        ArrayAXPBY(w, w, q, 1.0, 1.0/sr[m-1], N, backend);                  
}

void UpdateSolution(cublasHandle_t handle, dstype *x, dstype *y, dstype *H, dstype *s, dstype *V,
        Int i, Int N, Int n, Int backend)
{
    BackSolve(y, H, s, i, n, 0);
    PGEMNV(handle, N, i+1, &one, V, N, y, inc1, &one, x, inc1, backend);
}

Int GMRES(sysstruct &sys, CDiscretization &disc, CPreconditioner& prec, Int backend)
{
    INIT_TIMING;    
    
    Int maxit, nrest, orthogMethod, n1, i, k, j = 0;
    //Int nc = disc.common.nc;
    Int ncu = disc.common.ncu;
    Int npe = disc.common.npe;
    Int ne = disc.common.ne1;
    Int N = npe*ncu*ne;
    dstype nrmb, nrmr, tol, scalar;
    tol = min(0.01,disc.common.linearSolverTol*disc.common.linearSolverTolFactor);
    maxit = disc.common.linearSolverMaxIter;
    nrest = disc.common.gmresRestart;
    orthogMethod = disc.common.gmresOrthogMethod;
    n1 = nrest + 1;
                
    dstype *s, *y, *cs, *sn, *H;
    s = &sys.tempmem[0];
    y = &sys.tempmem[n1];
    cs = &sys.tempmem[2*n1];
    sn = &sys.tempmem[3*n1];
    H = &sys.tempmem[4*n1];
            
//     int m = disc.common.ppdegree;
//     getPoly(disc, sys, sys.lam, sys.randvect, sys.ipiv, N, m, backend);
//     for (int i=0; i<m; i++)
//         if (disc.common.mpiRank==0) cout<<sys.lam[2*m+i]<<"  "<<sys.lam[3*m+i]<<endl;
        
    // compute b
    //disc.evalResidual(sys.b, sys.u, backend);            
    nrmb = PNORM(disc.common.cublasHandle, N, sys.b, backend);    
    
    scalar = PNORM(disc.common.cublasHandle, N, sys.x, backend);    
    if (scalar>1e-12) {
        // r = A*x
        disc.evalMatVec(sys.r, sys.x, sys.u, sys.b, backend);

        // compute the new RHS vector: r = -b - A*x
        ArrayAXPBY(sys.r, sys.b, sys.r, minusone, minusone, N, backend);    

        // norm of the new RHS vector
        nrmr = PNORM(disc.common.cublasHandle, N, sys.r, backend);
    }
    else {
        ArrayAXPBY(sys.r, sys.b, sys.b, minusone, zero, N, backend);
        nrmr = nrmb;  
    }

    if (disc.common.mpiRank==0)
        cout<<"Old RHS Norm: "<<nrmb<<",  New RHS Norm: "<<nrmr<<endl; 
    
    disc.common.linearSolverTolFactor = nrmb/nrmr;
    tol = min(0.1,disc.common.linearSolverTol*disc.common.linearSolverTolFactor);
        
    //disc.common.ppdegree = 0;
    
    // compute r = P*r
    if (disc.common.ppdegree>1)
        ApplyPoly(sys.r, disc, sys, sys.q, sys.p, N, backend);    
    else if (disc.common.RBcurrentdim>=0)
        prec.ApplyPreconditioner(sys.r, sys, disc, backend);
        
    // compute ||r||
    nrmb = PNORM(disc.common.cublasHandle, N, sys.r, backend);
    nrmr = nrmb;
        
    j = 1;
    while (j < maxit) {
        // v = r/||r||
        ArrayAXPB(sys.v, sys.r, one/nrmr, zero, N, backend);
        
        // initialize s
        s[0] = nrmr;
        for (k=1; k<n1; k++)
            s[k] = zero;
        
        for (i = 0; i < nrest && j < maxit; i++, j++) {
            Int m = i + 1;
            
            // compute v[m] = A*v[i]
            START_TIMING;                        
            disc.evalMatVec(&sys.v[m*N], &sys.v[i*N], sys.u, sys.b, backend);            
            END_TIMING_DISC(0);    
                                    
            START_TIMING;                                    
            // compute v[m] = P*v[m]
            if (disc.common.ppdegree>1)
                ApplyPoly(&sys.v[m*N], disc, sys, sys.q, sys.p, N, backend);
            else if (disc.common.RBcurrentdim>=0) 
                prec.ApplyPreconditioner(&sys.v[m*N], sys, disc, backend);                            
            END_TIMING_DISC(2);    
                        
            // orthogonalize Krylov vectors
            START_TIMING;    
            if (orthogMethod == 0)
                MGS(disc.common.cublasHandle, sys.v, &H[n1*i], N, m, backend);
            else
                CGS(disc.common.cublasHandle, sys.v, &H[n1*i], y, N, m, backend);
            END_TIMING_DISC(1);    
            
            // Apply Givens rotation to compute s
            ApplyGivensRotation(&H[n1*i], s, cs, sn, i, 0);
            
            // compute relative error
            disc.common.linearSolverRelError = fabs(s[i+1])/nrmb;
            
            // check convergence and update solution: x = x + v*s
            if (disc.common.linearSolverRelError < tol) {                
                UpdateSolution(disc.common.cublasHandle, sys.x, y, H, s, sys.v, i, N, n1, backend);
                return j;
            }            
        }        
        
        // update solution: x = x + v*s
        UpdateSolution(disc.common.cublasHandle, sys.x, y, H, s, sys.v, nrest-1, N, n1, backend);
               
        // compute r = A*x
        disc.evalMatVec(sys.r, sys.x, sys.u, sys.b, backend);
                
        // r = -b - A*x
        ArrayAXPBY(sys.r, sys.b, sys.r, minusone, minusone, N, backend);
        
        // r = P*r = P*(-b-A*x)
        if (disc.common.ppdegree>1)
            ApplyPoly(sys.r, disc, sys, sys.q, sys.p, N, backend);
        else if (disc.common.RBcurrentdim>=0)
            prec.ApplyPreconditioner(sys.r, sys, disc, backend);            
        
        // compute relative error
        nrmr = PNORM(disc.common.cublasHandle, N, sys.r, backend);
        disc.common.linearSolverRelError = nrmr/nrmb;
        
        // check convergence
        if (disc.common.linearSolverRelError < tol) {
            return j;
        }
    }       
    
    if (disc.common.linearSolverRelError > tol) {
        if (disc.common.mpiRank==0) {
            printf("Warning: GMRES(%d) does not converge to the tolerance %g within % d iterations\n",nrest,tol,maxit);
            printf("Warning: The current relative error is %g \n",disc.common.linearSolverRelError);
        }
    }
    return j;
}


#endif

