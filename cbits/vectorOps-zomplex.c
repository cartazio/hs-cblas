
#include <complex.h>
#include <string.h>
#include "BLAS.h"
#include "vectorOps.h"

static void
zVectorClear (int n, double complex *z)
{
        memset(z, 0, n * 2 * sizeof(double));
}

static void
zVectorCopy (int n, const double complex *x, double complex *z)
{
        if (x != z) {
                memcpy(z, x, n * 2 * sizeof(double));
        }
}

void
zVectorConj (int n, const double complex *x, double complex *z)
{
        int i;
        for (i = 0; i < n; i++) {
                z[i] = conj(x[i]);
        }
}

void
zVectorScale (int n, const double complex *palpha, const double complex *x, double complex *z)
{
        double complex alpha = *palpha;
        
        if (alpha == 1) {
                zVectorCopy(n, x, z);
        } else if (alpha == 0) {
                zVectorClear(n, z);
        } else if (x == z) {
                blas_zscal(n, palpha, z, 1);
        } else {
                int i;
                for (i = 0; i < n; i++) {
                        z[i] = alpha * x[i];
                }
        }
}

void
zVectorShift (int n, const double complex *palpha, const double complex *x, double complex *z)
{
        double complex alpha = *palpha;
        
        if (alpha == 0) {
                zVectorCopy(n, x, z);
        } else {
                int i;
                for (i = 0; i < n; i++) {
                        z[i] = alpha + x[i];
                }
        }
}

void
zVectorNeg (int n, const double complex *x, double complex *z)
{
        int i;
        for (i = 0; i < n; i++) {
                z[i] = -x[i];
        }
}

void
zVectorAbs (int n, const double complex *x, double complex *z)
{
        int i;
        for (i = 0; i < n; i++) {
                z[i] = cabs(x[i]) + 0*I;
        }
}

static void
zsgn (const double complex x, double complex *z)
{
        double arg = carg(x);
        *z = cexp(0 + arg*I); /* TODO: use sincos if available */
}

void
zVectorSgn (int n, const double complex *x, double complex *z)
{
        int i;
        for (i = 0; i < n; i++) {
                zsgn(x[i], &(z[i]));
        }
}

void
zVectorInv (int n, const double complex *x, double complex *z)
{
        int i;
        for (i = 0; i < n; i++) {
                z[i] = 1.0 / x[i];
        }
}

static void
zVectorAxpy (int n, const double complex *palpha, const double complex *x, const double complex *y, double complex *z)
{
        double complex alpha = *palpha;
        
        if (alpha == 0) {
                zVectorCopy(n, y, z);
        } else if (y == z) {
                blas_zaxpy(n, palpha, x, 1, z, 1);
        } else if (alpha == 1 && x == z) {
                blas_zaxpy(n, palpha, y, 1, z, 1);
        } else {
                int i;
                for (i = 0; i < n; i++) {
                        z[i] = alpha * x[i] + y[i];
                }
        }
}

void
zVectorAxpby (int n, const double complex *palpha, const double complex *x, const double complex *pbeta, const double complex *y, double complex *z)
{
        double complex alpha = *palpha;
        double complex beta = *pbeta;        
                
        if (alpha == 0) {
                zVectorScale(n, pbeta, y, z);
        } else if (alpha == 1) {
                zVectorAxpy(n, pbeta, y, x, z);
        } else if (beta == 0) {
                zVectorScale(n, palpha, x, z);
        } else if (beta == 1) {
                zVectorAxpy(n, palpha, x, y, z);
        } else {
                int i;
                for (i = 0; i < n; i++) {
                        z[i] = alpha * x[i] + beta * y[i];
                }
        }
}

void
zVectorAdd (int n, const double complex *x, const double complex *y, double complex *z)
{
        dVectorAdd(2 * n, (const double *)x, (const double *)y, (double *)z);
}

void zVectorSub (int n, const double complex *x, const double complex *y, double complex *z)
{
        dVectorSub(2 * n, (const double *)x, (const double *)y, (double *)z);
}

void
zVectorMul (int n, const double complex *x, const double complex *y, double complex *z)
{
        if (y == z) {
                blas_ztbmv(BlasUpper, BlasNoTrans, BlasNonUnit, n, 0, x, 1,
                           z, 1);
        } else if (x == z) {
                blas_ztbmv(BlasUpper, BlasNoTrans, BlasNonUnit, n, 0, y, 1,
                           z, 1);
        } else {
                double complex one = 1;
                blas_zgbmv(BlasNoTrans, n, n, 0, 0, &one, x, 1, y, 1, 0, z, 1);
        }
}

void
zVectorDiv (int n, const double complex *x, const double complex *y, double complex *z)
{
        if (y == z) {
                blas_ztbsv(BlasUpper, BlasNoTrans, BlasNonUnit, n, 0, x, 1,
                           z, 1);
        } else if (x == z) {
                int i;
                for (i = 0; i < n; i++) {
                        z[i] = z[i] / y[i];
                }
        } else {
                int i;
                for (i = 0; i < n; i++) {
                        z[i] = x[i] / y[i];
                }
        }
}

void
zVectorExp (int n, const double complex *x, double complex *z)
{
        int i;
        for (i = 0; i < n; i++) {
                z[i] = cexp(x[i]);
        }
}

void
zVectorSqrt (int n, const double complex *x, double complex *z)
{
        int i;
        for (i = 0; i < n; i++) {
                z[i] = csqrt(x[i]);
        }
}

void
zVectorLog (int n, const double complex *x, double complex *z)
{
        int i;
        for (i = 0; i < n; i++) {
                z[i] = clog(x[i]);
        }        
}

void
zVectorPow (int n, const double complex *x, const double complex *y, double complex *z)
{
        int i;
        for (i = 0; i < n; i++) {
                z[i] = cpow(x[i], y[i]);
        }        
}

void
zVectorSin (int n, const double complex *x, double complex *z)
{
        int i;
        for (i = 0; i < n; i++) {
                z[i] = csin(x[i]);
        }                
}

void
zVectorCos (int n, const double complex *x, double complex *z)
{
        int i;
        for (i = 0; i < n; i++) {
                z[i] = ccos(x[i]);
        }                        
}

void
zVectorTan (int n, const double complex *x, double complex *z)
{
        int i;
        for (i = 0; i < n; i++) {
                z[i] = ctan(x[i]);
        }                                
}

void
zVectorASin (int n, const double complex *x, double complex *z)
{
        int i;
        for (i = 0; i < n; i++) {
                z[i] = casin(x[i]);
        }                                        
}

void
zVectorACos (int n, const double complex *x, double complex *z)
{
        int i;
        for (i = 0; i < n; i++) {
                z[i] = cacos(x[i]);
        }                                                
}

void
zVectorATan (int n, const double complex *x, double complex *z)
{
        int i;
        for (i = 0; i < n; i++) {
                z[i] = catan(x[i]);
        }
}

void
zVectorSinh (int n, const double complex *x, double complex *z)
{
        int i;
        for (i = 0; i < n; i++) {
                z[i] = csinh(x[i]);
        }                
}

void
zVectorCosh (int n, const double complex *x, double complex *z)
{
        int i;
        for (i = 0; i < n; i++) {
                z[i] = ccosh(x[i]);
        }                        
}

void
zVectorTanh (int n, const double complex *x, double complex *z)
{
        int i;
        for (i = 0; i < n; i++) {
                z[i] = ctanh(x[i]);
        }                                
}

void
zVectorASinh (int n, const double complex *x, double complex *z)
{
        int i;
        for (i = 0; i < n; i++) {
                z[i] = casinh(x[i]);
        }                                        
}

void
zVectorACosh (int n, const double complex *x, double complex *z)
{
        int i;
        for (i = 0; i < n; i++) {
                z[i] = cacosh(x[i]);
        }                                                
}

void
zVectorATanh (int n, const double complex *x, double complex *z)
{
        int i;
        for (i = 0; i < n; i++) {
                z[i] = catanh(x[i]);
        }
}

