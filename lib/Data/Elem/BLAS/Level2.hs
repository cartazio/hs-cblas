{-# LANGUAGE FlexibleInstances #-}
-----------------------------------------------------------------------------
-- |
-- Module     : Data.Elem.BLAS.Level2
-- Copyright  : Copyright (c) 2008, Patrick Perry <patperry@stanford.edu>
-- License    : BSD3
-- Maintainer : Patrick Perry <patperry@stanford.edu>
-- Stability  : experimental
--
-- Matrix-Vector operations.
--

module Data.Elem.BLAS.Level2
    where
     
import Data.Complex 
import Foreign ( Ptr, with, mallocForeignPtrArray, withForeignPtr )   

import BLAS.Types
import BLAS.CTypes
import Data.Elem.BLAS.Base( copy, vconj )
import Data.Elem.BLAS.Level1
import Data.Elem.BLAS.Double 
import Data.Elem.BLAS.Zomplex
   
-- | Types with matrix-vector operations.
class (BLAS1 a) => BLAS2 a where
    gemv :: TransEnum -> ConjEnum -> ConjEnum -> Int -> Int -> a -> Ptr a -> Int -> Ptr a -> Int -> a -> Ptr a -> Int -> IO ()
    gbmv :: TransEnum -> Int -> Int -> Int -> Int -> a -> Ptr a -> Int -> Ptr a -> Int -> a -> Ptr a -> Int -> IO ()
    trmv :: UpLoEnum -> TransEnum -> DiagEnum -> ConjEnum -> Int -> Ptr a -> Int -> Ptr a -> Int -> IO ()
    tbmv :: UpLoEnum -> TransEnum -> DiagEnum -> Int -> Int -> Ptr a -> Int -> Ptr a -> Int -> IO ()
    trsv :: UpLoEnum -> TransEnum -> DiagEnum -> Int -> Ptr a -> Int -> Ptr a -> Int -> IO ()
    tbsv :: UpLoEnum -> TransEnum -> DiagEnum -> Int -> Int -> Ptr a -> Int -> Ptr a -> Int -> IO ()
    hemv :: UpLoEnum -> ConjEnum -> ConjEnum -> Int -> a -> Ptr a -> Int -> Ptr a -> Int -> a -> Ptr a -> Int -> IO ()
    hbmv :: UpLoEnum -> Int -> Int -> a -> Ptr a -> Int -> Ptr a -> Int -> a -> Ptr a -> Int -> IO ()
    ger  :: ConjEnum -> ConjEnum -> TransEnum -> Int -> Int -> a -> Ptr a -> Int -> Ptr a -> Int -> Ptr a -> Int -> IO ()
    her  :: UpLoEnum -> Int -> a -> Ptr a -> Int -> Ptr a -> Int -> IO ()
    her2 :: UpLoEnum -> Int -> a -> Ptr a -> Int -> Ptr a -> Int -> Ptr a -> Int -> IO ()

instance BLAS2 Double where
    gemv t _ _ = dgemv (cblasTrans t)
    
    gbmv t = dgbmv (cblasTrans t)
    trmv u t d _ = dtrmv (cblasUpLo u) (cblasTrans t) (cblasDiag d)
    tbmv u t d = dtbmv (cblasUpLo u) (cblasTrans t) (cblasDiag d)
    trsv u t d = dtrsv (cblasUpLo u) (cblasTrans t) (cblasDiag d)
    tbsv u t d = dtbsv (cblasUpLo u) (cblasTrans t) (cblasDiag d)
    hemv u _ _ = dsymv (cblasUpLo u)
    hbmv u = dsbmv (cblasUpLo u)
    ger _ _ NoTrans m n alpha pX incX pY incY pA ldA = 
        dger m n alpha pX incX pY incY pA ldA
    ger _ _ ConjTrans m n alpha pX incX pY incY pA ldA = 
        dger m n alpha pY incY pX incX pA ldA
    her  u = dsyr  (cblasUpLo u)
    her2 u = dsyr2 (cblasUpLo u)
    
instance BLAS2 (Complex Double) where
    gemv transA conjX conjY m n alpha pA ldA pX incX beta pY incY =
        case (conjX,conjY) of
            (NoConj,NoConj) ->
                with alpha $ \pAlpha -> with beta $ \pBeta ->
                    zgemv (cblasTrans transA) m n pAlpha pA ldA pX incX pBeta pY incY
            (Conj,Conj) ->
                with (conjugate alpha) $ \pAlpha -> with (conjugate beta) $ \pBeta -> do
                    zgemm (cblasTrans NoTrans) (cblasTrans $ flipTrans transA) 1 m' n' pAlpha pX incX pA ldA pBeta pY incY
            _ -> do
                vconj m' pY incY
                gemv transA conjX (flipConj conjY) m n alpha pA ldA pX incX beta pY incY
                vconj m' pY incY
      where
        (m',n') = if transA == ConjTrans then (n,m) else (m,n)
    
    gbmv transA m n kl ku alpha pA ldA pX incX beta pY incY =
        with alpha $ \pAlpha -> with beta $ \pBeta ->
            zgbmv (cblasTrans transA) m n kl ku pAlpha pA ldA pX incX pBeta pY incY

    trmv u t d conjX n pA ldA pX incX
        | conjX == Conj =
            with 1 $ \pAlpha ->
                ztrmm (cblasSide RightSide) (cblasUpLo u) (cblasTrans $ flipTrans t) (cblasDiag d) 1 n pAlpha pA ldA pX incX
        | otherwise =
            ztrmv (cblasUpLo u) (cblasTrans t) (cblasDiag d) n pA ldA pX incX
            
    tbmv u t d = ztbmv (cblasUpLo u) (cblasTrans t) (cblasDiag d)
    trsv u t d = ztrsv (cblasUpLo u) (cblasTrans t) (cblasDiag d)
    tbsv u t d = ztbsv (cblasUpLo u) (cblasTrans t) (cblasDiag d)
    
    hemv uplo conjX conjY n alpha pA ldA pX incX beta pY incY
        | conjX == Conj = do
            fX' <- mallocForeignPtrArray n
            withForeignPtr fX' $ \pX' -> do
                copy Conj NoConj n pX incX pX' 1
                hemv uplo NoConj conjY n alpha pA ldA pX' 1 beta pY incY
        | conjY == Conj = do
            vconj n pY incY
            hemv uplo conjX NoConj n alpha pA ldA pX incX beta pY incY
            vconj n pY incY
        | otherwise =
            with alpha $ \pAlpha -> with beta $ \pBeta -> 
                zhemv (cblasUpLo uplo) n pAlpha pA ldA pX incX pBeta pY incY
    
    hbmv uplo n k alpha pA ldA pX incX beta pY incY =
        with alpha $ \pAlpha -> with beta $ \pBeta -> 
            zhbmv (cblasUpLo uplo) n k pAlpha pA ldA pX incX pBeta pY incY

    ger conjX conjY ConjTrans m n alpha pX incX pY incY pA ldA =
        ger conjY conjX NoTrans m n (conjugate alpha) pY incY pX incX pA ldA
        
    ger NoConj Conj NoTrans m n alpha pX incX pY incY pA ldA = 
        with alpha $ \pAlpha ->
            zgeru m n pAlpha pX incX pY incY pA ldA
            
    ger NoConj NoConj NoTrans m n alpha pX incX pY incY pA ldA = 
        with alpha $ \pAlpha ->
            zgerc m n pAlpha pX incX pY incY pA ldA
            
    ger Conj conjY NoTrans m n alpha pX incX pY incY pA ldA = do
        fX' <- mallocForeignPtrArray m
        withForeignPtr fX' $ \pX' -> do
            copy Conj NoConj m pX incX pX' 1
            ger NoConj conjY NoTrans m n alpha pX' 1 pY incY pA ldA

    her uplo n alpha pX incX pA ldA = 
        with alpha $ \pAlpha -> 
            zher (cblasUpLo uplo) n pAlpha pX incX pA ldA
    
    her2 uplo n alpha pX incX pY incY pA ldA = 
        with alpha $ \pAlpha ->
            zher2 (cblasUpLo uplo) n pAlpha pX incX pY incY pA ldA
