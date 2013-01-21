# -*- coding: utf-8 -*-

<%include file='views.cu.mak' />
<%include file='flux_inv.cu.mak' />

inline __device__ void
rsolve_rus_inv(const ${dtype} ul[${nvars}],
               const ${dtype} ur[${nvars}],
               const ${dtype} pnorm[${ndims}],
               ${dtype} fcomm[${nvars}])
{
    // Compute the left and right fluxes + velocities and pressures
    ${dtype} fl[${ndims}][${nvars}], fr[${ndims}][${nvars}];
    ${dtype} vl[${ndims}], vr[${ndims}];
    ${dtype} pl, pr;

    disf_inv(ul, fl, &pl, vl);
    disf_inv(ur, fr, &pr, vr);

    // Compute the speed/2
    ${dtype} a = sqrt(${0.25*gamma}*(pl + pr)/(ul[0] + ur[0]))
         + 0.25 * fabs(${' + '.join('pnorm[{0}]*(vl[{0}] + vr[{0}])'.format(k)\
                        for k in range(ndims))});

    // Output
    for (int i = 0; i < ${nvars}; ++i)
        fcomm[i] = 0.5 * (${' + '.join('pnorm[{0}]*(fl[{0}][i] + fr[{0}][i])'.format(k)\
                             for k in range(ndims))})
                 + a*(ul[i] - ur[i]);

}

__global__ void
rsolve_rus_inv_int(int ninters,
                   ${dtype}** __restrict__ ul_v,
                   const int* __restrict__ ul_vstri,
                   ${dtype}** __restrict__ ur_v,
                   const int* __restrict__ ur_vstri,
                   const ${dtype}* __restrict__ magpnorml,
                   const ${dtype}* __restrict__ magpnormr,
                   const ${dtype}* __restrict__ normpnorml)
{
    int iidx = blockIdx.x * blockDim.x + threadIdx.x;

    if (iidx < ninters)
    {
        ${dtype} ul[${nvars}], ur[${nvars}];

        // Dereference the views into memory
        READ_VIEW(ul, ul_v, ul_vstri, iidx, ${nvars});
        READ_VIEW(ur, ur_v, ur_vstri, iidx, ${nvars});

        // Load the left normalized physical normal
        ${dtype} ptemp[${ndims}];
        for (int i = 0; i < ${ndims}; ++i)
            ptemp[i] = normpnorml[ninters*i + iidx];

        // Perform the Riemann solve
        ${dtype} fn[${nvars}];
        rsolve_rus_inv(ul, ur, ptemp, fn);

        // Write out the fluxes into ul and ur
        for (int i = 0; i < ${nvars}; ++i)
        {
            ul[i] =  magpnorml[iidx]*fn[i];
            ur[i] = -magpnormr[iidx]*fn[i];
        }

        // Copy back into the views
        WRITE_VIEW(ul_v, ul_vstri, ul, iidx, ${nvars});
        WRITE_VIEW(ur_v, ur_vstri, ur, iidx, ${nvars});
    }
}

__global__ void
rsolve_rus_inv_mpi(int ninters,
                   ${dtype}** __restrict__ ul_v,
                   const int* __restrict__ ul_vstri,
                   const ${dtype}* __restrict__ ur_m,
                   const ${dtype}* __restrict__ magpnorml,
                   const ${dtype}* __restrict__ normpnorml)
{
    int iidx = blockIdx.x * blockDim.x + threadIdx.x;

    if (iidx < ninters)
    {
        ${dtype} ptemp[${ndims}], ul[${nvars}], ur[${nvars}];

        // Load the left hand side (local) solution
        READ_VIEW(ul, ul_v, ul_vstri, iidx, ${nvars});

        // Load the left normalized physical normal
        for (int i = 0; i < ${ndims}; ++i)
            ptemp[i] = normpnorml[ninters*i + iidx];

        // Load the right hand (MPI) side solution matrix
        READ_MPIM(ur, ur_m, iidx, ninters, ${nvars});

        // Perform the Riemann solve
        ${dtype} fn[${nvars}];
        rsolve_rus_inv(ul, ur, ptemp, fn);

        // Write out the fluxes into ul
        for (int i = 0; i < ${nvars}; ++i)
            ul[i] = magpnorml[iidx]*fn[i];

        // Copy these back into the view
        WRITE_VIEW(ul_v, ul_vstri, ul, iidx, ${nvars});
    }
}