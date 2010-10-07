{-# LANGUAGE DeriveDataTypeable, FlexibleContexts, Rank2Types #-}
-----------------------------------------------------------------------------
-- |
-- Module     : Numeric.LinearAlgebra.Packed.Base
-- Copyright  : Copyright (c) 2010, Patrick Perry <patperry@gmail.com>
-- License    : BSD3
-- Maintainer : Patrick Perry <patperry@gmail.com>
-- Stability  : experimental
--
-- Packed matrices.
--
module Numeric.LinearAlgebra.Packed.Base
    where

import Control.Monad.ST( ST, RealWorld, runST, unsafeIOToST )
import Data.Typeable( Typeable )
import Foreign( Storable, Ptr )
import Text.Printf( printf )

import Numeric.LinearAlgebra.Types( Herm(..) )
import Numeric.LinearAlgebra.Vector( Vector, RVector, STVector )
import qualified Numeric.LinearAlgebra.Vector as V
import Foreign.BLAS( BLAS2 )
import qualified Foreign.BLAS as BLAS


-- | Immutable packed matrices, stored in column-major order.
data Packed e = Packed !Int !(Vector e)
    deriving (Typeable)
    
-- | Mutable packed matrices in the 'ST' monad.
data STPacked s e = STPacked !Int !(STVector s e)
    deriving (Typeable)
    
-- | Mutable packed matrices in the 'IO' monad.
type IOPacked = STPacked RealWorld

-- | Allocate a mutable packed matrix of the given dimension.
new_ :: (Storable e) => Int -> ST s (STPacked s e)
new_ n
    | n < 0 = error $
        printf "new_ %d: negative dimension" n
    | otherwise = do
        x <- V.new_ (n*(n+1) `div` 2)
        return $ unsafeFromSTVector n x
{-# INLINE new_ #-}

-- | Create a packed matrix view of a vector, ensurint that the
-- vector has dimension @n * (n+1)/2@, where @n@ is the desired dimension.
fromVector :: (Storable e) => Int -> Vector e -> Packed e
fromVector n x
    | not $ 2 * nx == n * (n+1) = error $
        printf ("fromVector %d <vector with dim %d>: dimension mismatch")
               n nx
    | otherwise =
        unsafeFromVector n x
  where
    nx = V.dim x
{-# INLINE fromVector #-}

-- | Create a packed matrix view of a vector, wihtout checking
-- the dimension of the vector.
unsafeFromVector :: (Storable e) => Int -> Vector e -> Packed e
unsafeFromVector = Packed
{-# INLINE unsafeFromVector #-}

-- | Returns the dimension and underlying vector storage of a
-- packed matrix.
toVector :: (Storable e) => Packed e -> (Int, Vector e)
toVector (Packed n v) = (n,v)
{-# INLINE toVector #-}

-- | Create a packed matrix view of a vector, ensurint that the
-- vector has dimension @n * (n+1)/2@, where @n@ is the desired dimension.
fromSTVector :: (Storable e) => Int -> STVector s e -> STPacked s e
fromSTVector n x
    | not $ 2 * nx == n * (n+1) = error $
        printf ("fromVectorST %d <vector with dim %d>: dimension mismatch")
               n nx
    | otherwise =
        STPacked n x
  where
    nx = V.dim x
{-# INLINE fromSTVector #-}

-- | Create a packed matrix view of a vector, wihtout checking
-- the dimension of the vector.
unsafeFromSTVector :: (Storable e) => Int -> STVector s e -> STPacked s e
unsafeFromSTVector = STPacked
{-# INLINE unsafeFromSTVector #-}

{-
-- | Returns the dimension and underlying vector storage of a
-- packed matrix.
toSTVector :: (Storable e) => STPacked s e -> (Int, STVector s e)
toSTVector (STPacked n v) = (n,v)
{-# INLINE toSTVector #-}
-}

-- | Read-only packed matrices.
class RPacked p where
    -- | Returns the dimension of the packed matrix.
    dim :: (Storable e) => p e -> Int

    -- | Perform an action with the underlying vector storage of
    -- the packed matrix.
    withVectorView :: (Storable e)
                   => p e
                   -> (forall v . RVector v => v e -> ST s a)
                   -> ST s a
    
    -- | Perform an IO action with a pointer to the first element of
    -- the packed matrix.
    unsafeWith :: (Storable e) => p e -> (Ptr e -> IO a) -> IO a

-- | View a vector as a packed matrix and pass it to a function.
withViewFromVector :: (RVector v, Storable e)
                   => Int
                   -> v e
                   -> (forall p . RPacked p => p e -> ST s a)
                   -> ST s a
withViewFromVector n v f = f (cast v)
  where
    cast :: (RVector v, Storable e) => v e -> Packed e
    cast x = let
        (fptr,o,d) = V.unsafeToForeignPtr x
        x' = V.unsafeFromForeignPtr fptr o d
        in fromVector n x'
{-# INLINE withViewFromVector #-}

-- | View a mutable vector as a mutable packed matrix and pass it
-- to a function.
withViewFromSTVector :: (Storable e)
                     => Int
                     -> STVector s e
                     -> (STPacked s e -> ST s a)
                     -> ST s a
withViewFromSTVector n v f = f $ fromSTVector n v
{-# INLINE withViewFromSTVector #-}

-- | Perform an action with the underlying vector storage of
-- the mutable packed matrix.  See also 'withVectorView'.
withSTVectorView :: (Storable e)
                 => STPacked s e
                 -> (STVector s e -> ST s a)
                 -> ST s a
withSTVectorView (STPacked _ v) f = f v
{-# INLINE withSTVectorView #-}

instance RPacked Packed where
    dim (Packed n _) = n
    {-# INLINE dim #-}
    withVectorView (Packed _ v) f = f v
    {-# INLINE withVectorView #-}
    unsafeWith (Packed _ v) = V.unsafeWith v
    {-# INLINE unsafeWith #-}

instance RPacked (STPacked s) where
    dim (STPacked n _) = n
    {-# INLINE dim #-}
    withVectorView (STPacked _ v) f = f v
    {-# INLINE withVectorView #-}
    unsafeWith (STPacked _ v) = V.unsafeWith v
    {-# INLINE unsafeWith #-}


-- | Create a new copy of a packed matrix.
newCopy :: (Storable e, RPacked p)
              => p e -> ST s (STPacked s e)
newCopy p =
    withVectorView p $ \x ->
        unsafeFromSTVector (dim p) `fmap` V.newCopy x
{-# INLINE newCopy #-}

-- | Converts a mutable packed matrix to an immutable one by taking a complete
-- copy of it.
freeze :: (Storable e) => STPacked s e -> ST s (Packed e)
freeze (STPacked n mp) = do
    p <- V.freeze mp
    return $ Packed n p

-- | Converts a mutable matrix into an immutable matrix. This simply casts
-- the matrix from one type to the other without copying the matrix. Note
-- that because the matrix is possibly not copied, any subsequent
-- modifications made to the mutable version of the matrix may be shared with
-- the immutable version. It is safe to use, therefore, if the mutable
-- version is never modified after the freeze operation.
unsafeFreeze :: (Storable e) => STPacked s e -> ST s (Packed e)
unsafeFreeze (STPacked n mp) = do
    p <- V.unsafeFreeze mp
    return $ Packed n p

-- | A safe way to create and work with a mutable Packed before returning 
-- an immutable one for later perusal.
create :: (Storable e)
       => (forall s. ST s ((STPacked s) e))
       -> Packed e
create stmp = runST $ do
    mp <- stmp
    unsafeFreeze mp


-- | A safe way to create and work with a mutable Herm Packed before returning 
-- an immutable one for later perusal.
hermCreate :: (Storable e)
           => (forall s. ST s (Herm (STPacked s) e))
           -> Herm Packed e
hermCreate stmh = runST $ do
    (Herm u mp) <- stmh
    p <- unsafeFreeze mp
    return $ Herm u p

-- | @hermRank1Update alpha x a@ returns
-- @alpha * x * x^H + a@.
hermRank1Update :: (BLAS2 e)
                => Double -> Vector e -> Herm Packed e -> Herm Packed e
hermRank1Update alpha x (Herm uplo ap) = hermCreate $ do
    hp' <- Herm uplo `fmap` newCopy ap
    hermRank1UpdateM_ alpha x hp'
    return hp'

-- | @hermRank2Update alpha x y a@ returns
-- @alpha * x * y^H + conj(alpha) * y * x^H + a@.
hermRank2Update :: (BLAS2 e)
                => e -> Vector e -> Vector e -> Herm Packed e
                -> Herm Packed e
hermRank2Update alpha x y (Herm uplo ap) = hermCreate $ do
    hp' <- Herm uplo `fmap` newCopy ap
    hermRank2UpdateM_ alpha x y hp'
    return hp'

-- | @hermRank1UpdateM_ alpha x a@ sets
-- @a := alpha * x * x^H + a@.
hermRank1UpdateM_ :: (RVector v, BLAS2 e)
                  => Double -> v e -> Herm (STPacked s) e -> ST s ()
hermRank1UpdateM_ alpha x (Herm uplo a)
    | (not . and) [ nx == n, na == n ] = error $
        printf ("hermRank1UpdateM_ _ <vector with dim %d>"
                 ++ " (Herm _ <packed matrix with dim %d>):"
                 ++ " invalid dimensions") nx na
    | otherwise =
        unsafeIOToST $
        V.unsafeWith x $ \px ->
        unsafeWith a $ \pa ->
            BLAS.hpr uplo n alpha px 1 pa
  where
    nx = V.dim x
    na = dim a
    n = nx

-- | @hermRank2UpdateM_ alpha x y a@ sets
-- @a := alpha * x * y^H + conj(alpha) * y * x^H + a@.
hermRank2UpdateM_ :: (RVector v1, RVector v2, BLAS2 e)
                  => e -> v1 e -> v2 e -> Herm (STPacked s) e -> ST s ()
hermRank2UpdateM_ alpha x y (Herm uplo a)
    | (not . and) [ nx == n, ny == n, na == n ] = error $
        printf ("hermRank2UpdateM_ _ <vector with dim %d>"
                 ++ " <vector with dim %d>"
                 ++ " (Herm _ <packed matrix with dim %d>):"
                 ++ " invalid dimensions") nx ny na
    | otherwise =
        unsafeIOToST $
        V.unsafeWith x $ \px ->
        V.unsafeWith y $ \py ->        
        unsafeWith a $ \pa ->
            BLAS.hpr2 uplo n alpha px 1 py 1 pa
  where
    nx = V.dim x
    ny = V.dim y
    na = dim a
    n = nx

-- | @hermMulVector a x@ returns @a * x@.
hermMulVector :: (BLAS2 e)
                    => Herm Packed e
                    -> Vector e
                    -> Vector e
hermMulVector a x =
    V.create $ do
        y <- V.new_ (V.dim x)
        hermMulVectorTo y a x
        return y

-- | @hermMulVectorWithScale alpha a x@ retunrs @alpha * a * x@.
hermMulVectorWithScale :: (BLAS2 e)
                       => e
                       -> Herm Packed e
                       -> Vector e
                       -> Vector e
hermMulVectorWithScale alpha a x =
    V.create $ do
        y <- V.new_ (V.dim x)
        hermMulVectorWithScaleTo y alpha a x
        return y
                       
-- | @addHermMulVectorWithScales alpha a x y@
-- returns @alpha * a * x + beta * y@.
addHermMulVectorWithScales :: (BLAS2 e)
                           => e
                           -> Herm Packed e
                           -> Vector e
                           -> e
                           -> Vector e
                           -> Vector e
addHermMulVectorWithScales alpha a x beta y =
    V.create $ do
        y' <- V.newCopy y
        addHermMulVectorWithScalesM_ alpha a x beta y'
        return y'

-- | @hermMulVectorTo dst a x@ sets @dst := a * x@.
hermMulVectorTo :: (RPacked p, RVector v, BLAS2 e)
                => STVector s e
                -> Herm p e
                -> v e
                -> ST s ()
hermMulVectorTo dst = hermMulVectorWithScaleTo dst 1

-- | @hermMulVectorWithScaleTo dst alpha a x@
-- sets @dst := alpha * a * x@.
hermMulVectorWithScaleTo :: (RPacked p, RVector v, BLAS2 e)
                         => STVector s e
                         -> e
                         -> Herm p e
                         -> v e
                         -> ST s ()
hermMulVectorWithScaleTo dst alpha a x =
    addHermMulVectorWithScalesM_ alpha a x 0 dst

-- | @addHermMulVectorWithScalesM_ alpha a x beta y@
-- sets @y := alpha * a * x + beta * y@.
addHermMulVectorWithScalesM_ :: (RPacked p, RVector v, BLAS2 e)
                             => e
                             -> Herm p e
                             -> v e
                             -> e
                             -> STVector s e
                             -> ST s ()
addHermMulVectorWithScalesM_ alpha (Herm uplo a) x beta y
    | (not . and) [ na == n
                  , nx == n
                  , ny == n
                  ] = error $
        printf ("addHermMulVectorWithScalesM_ _"
                ++ " (Herm %s <packed matrix with dim %d>)"
                ++ " %s <vector with dim %d>"
                ++ " _"
                ++ " <vector with dim %d>: dimension mismatch")
               (show uplo) na
               nx ny

    | otherwise =
        unsafeIOToST $
            unsafeWith a $ \pa ->
            V.unsafeWith x $ \px ->
            V.unsafeWith y $ \py ->
                BLAS.hpmv uplo n alpha pa px 1 beta py 1
  where
    na = dim a
    nx = V.dim x
    ny = V.dim y
    n = ny
