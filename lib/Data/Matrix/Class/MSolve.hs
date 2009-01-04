{-# LANGUAGE MultiParamTypeClasses #-}
-----------------------------------------------------------------------------
-- |
-- Module     : Data.Matrix.Class.MSolve
-- Copyright  : Copyright (c) , Patrick Perry <patperry@stanford.edu>
-- License    : BSD3
-- Maintainer : Patrick Perry <patperry@stanford.edu>
-- Stability  : experimental
--

module Data.Matrix.Class.MSolve (
    
    -- * Matrix and vector solving
    getSolve,
    getSolveMat,
    getSSolve,
    getSSolveMat,
    
    -- * In-place solving
    doSolve,
    doSolveMat,
    doSSolve,
    doSSolveMat,
    doSolve_,
    doSolveMat_,
    doSSolve_,
    doSSolveMat_,
    
    -- * The MSolve typeclass
    MSolve(..),

    -- * Unsafe operations
    unsafeGetSolve,
    unsafeGetSolveMat,
    unsafeGetSSolve,
    unsafeGetSSolveMat,

    ) where

import Data.Matrix.Class
import BLAS.Internal ( checkMatVecSolv, checkMatMatSolv, checkMatVecSolvTo,
    checkMatMatSolvTo, checkSquare )

import Data.Vector.Dense.Class
import Data.Matrix.Dense.Class.Internal


unsafeGetSolve :: (MSolve a e m, ReadVector y e m, WriteVector x e m) => 
    a (k,l) e -> y k e -> m (x l e)
unsafeGetSolve a y = do
    x <- newVector_ (numCols a)
    unsafeDoSolve a y x
    return x
    
unsafeGetSSolve :: (MSolve a e m, ReadVector y e m, WriteVector x e m) => 
    e -> a (k,l) e -> y k e -> m (x l e)
unsafeGetSSolve alpha a y = do
    x <- newVector_ (numCols a)
    unsafeDoSSolve alpha a y x
    return x
    
unsafeGetSolveMat :: (MSolve a e m, ReadMatrix c e m, WriteMatrix b e m) => 
    a (r,s) e -> c (r,t) e -> m (b (s,t) e)
unsafeGetSolveMat a c = do
    b <- newMatrix_ (numCols a, numCols c)
    unsafeDoSolveMat a c b
    return b

unsafeGetSSolveMat :: (MSolve a e m, ReadMatrix c e m, WriteMatrix b e m) => 
    e -> a (r,s) e -> c (r,t) e -> m (b (s,t) e)                         
unsafeGetSSolveMat alpha a c = do
    b <- newMatrix_ (numCols a, numCols c)
    unsafeDoSSolveMat alpha a c b
    return b

-- | Solve for a vector
getSolve :: (MSolve a e m, ReadVector y e m, WriteVector x e m) =>
    a (k,l) e -> y k e -> m (x l e)
getSolve a y = 
    checkMatVecSolv (shape a) (dim y) $
        unsafeGetSolve a y

-- | Solve for a vector and scale
getSSolve :: (MSolve a e m, ReadVector y e m, WriteVector x e m) => 
    e -> a (k,l) e -> y k e -> m (x l e)
getSSolve alpha a y = 
    checkMatVecSolv (shape a) (dim y) $
        unsafeGetSSolve alpha a y

-- | Solve for a matrix
getSolveMat :: (MSolve a e m, ReadMatrix c e m, WriteMatrix b e m) => 
    a (r,s) e -> c (r,t) e -> m (b (s,t) e)                     
getSolveMat a c =
    checkMatMatSolv (shape a) (shape c) $
            unsafeGetSolveMat a c
            
-- | Solve for a matrix and scale
getSSolveMat :: (MSolve a e m, ReadMatrix c e m, WriteMatrix b e m) => 
    e -> a (r,s) e -> c (r,t) e -> m (b (s,t) e)                 
getSSolveMat alpha a b =
    checkMatMatSolv (shape a) (shape b) $
            unsafeGetSSolveMat alpha a b

doSolve :: (MSolve a e m, ReadVector y e m, WriteVector x e m) => 
    a (r,s) e -> y r e -> x s e -> m ()                 
doSolve a y x =
    checkMatVecSolvTo (shape a) (dim y) (dim x) $
        unsafeDoSolve a y x
        
doSolveMat :: (MSolve a e m, ReadMatrix c e m, WriteMatrix b e m) => 
    a (r,s) e -> c (r,t) e -> b (s,t) e -> m ()                
doSolveMat a c b =
    checkMatMatSolvTo (shape a) (shape c) (shape b) $
        unsafeDoSolveMat a c b
    
doSSolve :: (MSolve a e m, ReadVector y e m, WriteVector x e m) => 
    e -> a (k,l) e -> y k e -> x l e -> m ()
doSSolve alpha a y x =
    checkMatVecSolvTo (shape a) (dim y) (dim x) $
        unsafeDoSSolve alpha a y x

doSSolveMat :: (MSolve a e m, ReadMatrix c e m, WriteMatrix b e m) => 
    e -> a (r,s) e -> c (r,t) e -> b (s,t) e -> m ()                  
doSSolveMat alpha a c b =
    checkMatMatSolvTo (shape a) (shape c) (shape b) $
        unsafeDoSSolveMat alpha a c b

doSolve_ :: (MSolve a e m, ReadVector y e m, WriteVector x e m) => 
    a (k,k) e -> x k e -> m ()
doSolve_ a x =
    checkSquare (shape a) $
        checkMatVecSolv (shape a) (dim x) $
            unsafeDoSolve_ a x

doSSolve_ :: (MSolve a e m, WriteVector x e m) => 
    e -> a (k,k) e -> x k e -> m ()
doSSolve_ alpha a x =
    checkSquare (shape a) $
        checkMatVecSolv (shape a) (dim x) $
            unsafeDoSSolve_ alpha a x

doSolveMat_ :: (MSolve a e m, WriteMatrix b e m) => 
    a (k,k) e -> b (k,l) e -> m ()          
doSolveMat_ a b =
    checkSquare (shape a) $
        checkMatMatSolv (shape a) (shape b) $
            unsafeDoSolveMat_ a b

doSSolveMat_ :: (MSolve a e m, WriteMatrix b e m) =>
    e -> a (k,k) e -> b (k,l) e -> m ()          
doSSolveMat_ alpha a b =
    checkSquare (shape a) $
        checkMatMatSolv (shape a) (shape b) $
            unsafeDoSSolveMat_ alpha a b