{-# LANGUAGE Rank2Types, ScopedTypeVariables #-}
module STVector
    where


import Data.Elem.BLAS
import Data.Vector.Dense
import Data.Vector.Dense.ST

import qualified Test.Vector.Dense as Test

import Driver



---------------------------- Creating Vectors --------------------------------

newVector_S n ies = 
    (snd . unzip) $ sortAssocs $ 
        unionBy ((==) `on` fst) 
                (nubAssocs ies)
                (zip [0..(n-1)] (repeat 0))
  where
    nubAssocs = reverse . nubBy ((==) `on` fst) . reverse      
    sortAssocs = sortBy (comparing fst)

prop_NewVector (Assocs n ies) =
    newVector n ies `equivalent` newVector_S n ies

newListVector_S n es = take n $ es ++ repeat 0
prop_NewListVector (Nat n) es =
    newListVector n es `equivalent` newListVector_S n es


---------------------- Reading and Writing Elements --------------------------

getSize_S x = ( length x, x )
prop_GetSize = getSize `implements` getSize_S

readElem_S x i = ( x !! i, x )
prop_ReadElem (Index n i) =
    implementsFor n (`readElem` i) (`readElem_S` i)

canModifyElem_S x i = ( True, x )
prop_CanModifyElem i = (`canModifyElem` i) `implements` (`canModifyElem_S` i)

writeElem_S x i e = ( (), take i x ++ [e] ++ drop (i+1) x )
prop_WriteElem (Index n i) e =
    implementsFor n (\x -> writeElem x i e) (\x -> writeElem_S x i e)

modifyElem_S x i f = writeElem_S x i $ f (x!!i)
prop_ModifyElem (Index n i) f =
    implementsFor n (\x -> modifyElem x i f) (\x -> modifyElem_S x i f)

getIndices_S x = ( [0..(length x - 1)], x )
prop_GetIndicesLazy = getIndices `implements` getIndices_S
prop_GetIndicesStrict = getIndices' `implements` getIndices_S

getElemsLazyModifyWith_S f x = ( y, y ) where y = map f x
prop_GetElemsLazyModifyWith f = 
    (\x -> do { es <- getElems x ; modifyWith f x ; return es })
    `implements` 
    getElemsLazyModifyWith_S f

getElemsStrictModifyWith_S f x = ( x, y ) where y = map f x
prop_GetElemsStrictModifyWith f =
    (\x -> do { es <- getElems' x ; modifyWith f x ; return es })
    `implements` 
    getElemsStrictModifyWith_S f

getAssocsLazyModifyWith_S f x = ( zip [0..] y, y ) where y = map f x
prop_GetAssocsLazyModifyWith f =
    (\x -> do { ies <- getAssocs x ; modifyWith f x ; return ies })
    `implements` 
    getAssocsLazyModifyWith_S f

getAssocsStrictModifyWith_S f x = ( zip [0..] x, y ) where y = map f x
prop_GetAssocsStrictModifyWith f =
    (\x -> do { ies <- getAssocs' x ; modifyWith f x ; return ies })
    `implements` 
    getAssocsStrictModifyWith_S f


----------------------------- Special Vectors --------------------------------

newZeroVector_S n = replicate n 0
prop_NewZeroVector (Nat n) = 
    newZeroVector n `equivalent` newZeroVector_S n

setZero_S x = ( (), newZeroVector_S (length x) )
prop_SetZero = setZero `implements` setZero_S

newConstantVector_S n e = replicate n e
prop_NewConstantVector (Nat n) e = 
    newConstantVector n e `equivalent` newConstantVector_S n e

setConstant_S e x = ( (), newConstantVector_S (length x) e )
prop_SetConstant e = setConstant e `implements` setConstant_S e

newBasisVector_S n i = replicate i 0 ++ [1] ++ replicate (n-i-1) 0
prop_NewBasisVector (Index n i) = 
    newBasisVector n i `equivalent` newBasisVector_S n i

setBasisVector_S i x = ( (), newBasisVector_S (length x) i )
prop_SetBasisVector (Index n i) = 
    implementsFor n (setBasisVector i) (setBasisVector_S i)


----------------------------- Copying Vectors --------------------------------

newCopyVector_S x = ( x, x )
prop_NewCopyVector = 
    (\x -> newCopyVector x >>= abstract) `implements` newCopyVector_S

copyVector_S x y = ( (), y, y )
prop_CopyVector = copyVector `implements2` copyVector_S

swapVector_S x y = ( (), y, x )
prop_SwapVector = swapVector `implements2` swapVector_S


-------------------------- Unsary Vector Operations --------------------------

doConj_S x = ( (), map conjugate x )
prop_DoConj = doConj `implements` doConj_S

scaleBy_S k x = ( (), map (k*) x )
prop_ScaleBy k = scaleBy k `implements` scaleBy_S k

shiftBy_S k x = ( (), map (k+) x )
prop_ShiftBy k = shiftBy k `implements` shiftBy_S k

modifyWith_S f x = ( (), map f x )
prop_ModifyWith f = modifyWith f `implements` modifyWith_S f

getConjVector_S x = ( map conjugate x, x )
prop_GetConjVector = 
    (\x -> getConjVector x >>= abstract) `implements` getConjVector_S

getScaledVector_S k x = ( map (k*) x, x )
prop_GetScaledVector k = 
    (\x -> getScaledVector k x >>= abstract) `implements` (getScaledVector_S k)

getShiftedVector_S k x = ( map (k+) x, x )
prop_GetShiftedVector k = 
    (\x -> getShiftedVector k x >>= abstract) `implements` (getShiftedVector_S k)


------------------------- Binary Vector Operations ---------------------------

addVector_S x y = ( (), zipWith (+) x y, y )
prop_AddVector = addVector `implements2` addVector_S

subVector_S x y = ( (), zipWith (-) x y, y )
prop_SubVector = subVector `implements2` subVector_S

axpyVector_S alpha x y = ( (), x, zipWith (\xi yi -> alpha * xi + yi) x y )
prop_AxpyVector alpha = axpyVector alpha `implements2` axpyVector_S alpha

mulVector_S x y = ( (), zipWith (*) x y, y )
prop_MulVector = mulVector `implements2` mulVector_S

divVector_S x y = ( (), zipWith (/) x y, y )
prop_DivVector = divVector `implements2` divVector_S

getAddVector_S x y = ( zipWith (+) x y, x, y )
prop_GetAddVector =
    (\x y -> getAddVector x y >>= abstract) `implements2` getAddVector_S

getSubVector_S x y = ( zipWith (-) x y, x, y )
prop_GetSubVector =
    (\x y -> getSubVector x y >>= abstract) `implements2` getSubVector_S

getMulVector_S x y = ( zipWith (*) x y, x, y )
prop_GetMulVector =
    (\x y -> getMulVector x y >>= abstract) `implements2` getMulVector_S

getDivVector_S x y = ( zipWith (/) x y, x, y )
prop_GetDivVector =
    (\x y -> getDivVector x y >>= abstract) `implements2` getDivVector_S


-------------------------- Vector Properties ---------------------------------

getSumAbs_S x = ( foldl' (+) 0 $ map norm1 x, x )
prop_GetSumAbs = getSumAbs `implements` getSumAbs_S

getNorm2_S x = ( sqrt $ foldl' (+) 0 $ map (**2) $ map norm x, x )
prop_GetNorm2 = getNorm2 `implements` getNorm2_S

getWhichMaxAbs_S x = ( (i,x!!i), x) 
    where i = fst $ maximumBy (comparing snd) $ reverse $ zip [0..] $ map norm1 x
prop_GetWhichMaxAbs = 
    implementsIf (return . (>0) . dim) getWhichMaxAbs getWhichMaxAbs_S

getDot_S x y = ( foldl' (+) 0 $ zipWith (*) (map conjugate x) y, x, y )
prop_GetDot = getDot `implements2` getDot_S


------------------------------------------------------------------------
-- 
-- The specification language
--
    
abstract :: (BLAS1 e) => STVector s e -> ST s [e]
abstract = getElems'

commutes :: (AEq a, Show a, AEq e, BLAS1 e) =>
    STVector s e -> (STVector s e -> ST s a) ->
        ([e] -> (a,[e])) -> ST s Bool
commutes x a f = do
    old <- abstract x
    r <- a x
    new <- abstract x
    let s      = f old
        s'     = (r,new)
        passed = s ~== s'
        
    when (not passed) $
        trace (printf ("expected `%s' but got `%s'") (show s) (show s'))
              return ()
              
    return passed

commutes2 :: (AEq a, Show a, AEq e, BLAS1 e) =>
    STVector s e -> STVector s e -> 
    (STVector s e ->  STVector s e -> ST s a) ->
        ([e] -> [e] -> (a,[e],[e])) -> ST s Bool
commutes2 x y a f = do
    oldX <- abstract x
    oldY <- abstract y
    r <- a x y
    newX <- abstract x
    newY <- abstract y
    let s      = f oldX oldY
        s'     = (r,newX,newY)
        passed = s ~== s'
        
    when (not passed) $
        trace (printf ("expected `%s' but got `%s'") (show s) (show s'))
            return ()
            
    return passed

equivalent :: (forall s . ST s (STVector s E)) -> [E] -> Bool
equivalent x s = runST $ do
    x' <- (x >>= abstract)
    when (not $ x' === s) $
        trace (printf ("expected `%s' but got `%s'") (show s) (show x'))
            return ()
    return (x' === s)
    
implements :: (AEq a, Show a) =>
    (forall s . STVector s E -> ST s a) ->
    ([E] -> (a,[E])) -> 
        Property
a `implements` f =
    forAll arbitrary $ \(Nat n) ->
        implementsFor n a f

implements2 :: (AEq a, Show a) =>
    (forall s . STVector s E -> STVector s E -> ST s a) ->
    ([E] -> [E] -> (a,[E],[E])) -> 
        Property
a `implements2` f =
    forAll arbitrary $ \(Nat n) ->
        implementsFor2 n a f

implementsFor :: (AEq a, Show a) =>
    Int ->
    (forall s . STVector s E -> ST s a) ->
    ([E] -> (a,[E])) -> 
        Property
implementsFor n a f =
    forAll (Test.vector n) $ \x ->
        runST $ do
            x' <- unsafeThawVector x
            commutes x' a f

implementsFor2 :: (AEq a, Show a) =>
    Int ->
    (forall s . STVector s E -> STVector s E -> ST s a) ->
    ([E] -> [E] -> (a,[E],[E])) -> 
        Property
implementsFor2 n a f =
    forAll (Test.vector n) $ \x ->
    forAll (Test.vector n) $ \y ->
        runST $ do
            x' <- unsafeThawVector x
            y' <- unsafeThawVector y
            commutes2 x' y' a f

implementsIf :: (AEq a, Show a) =>
    (forall s . STVector s E -> ST s Bool) ->
    (forall s . STVector s E -> ST s a) ->
    ([E] -> (a,[E])) -> 
        Property
implementsIf pre a f =
    forAll arbitrary $ \(Nat n) ->
    forAll (Test.vector n) $ \x ->
        runST ( do
            x' <- thawVector x
            pre x') ==>
        runST ( do
            x' <- unsafeThawVector x
            commutes x' a f )

implementsIf2 :: (AEq a, Show a) =>
    (forall s . STVector s E -> STVector s E -> ST s Bool) ->
    (forall s . STVector s E -> STVector s E -> ST s a) ->
    ([E] -> [E] -> (a,[E],[E])) -> 
        Property
implementsIf2 pre a f =
    forAll arbitrary $ \(Nat n) ->
    forAll (Test.vector n) $ \x ->
    forAll (Test.vector n) $ \y ->
        runST ( do
            x' <- thawVector x
            y' <- thawVector y
            pre x' y') ==>
        runST ( do
            x' <- unsafeThawVector x
            y' <- unsafeThawVector y
            commutes2 x' y' a f )

            
------------------------------------------------------------------------

tests_STVector =
    [ testProperty "newVector" prop_NewVector
    , testProperty "newListVector" prop_NewListVector
    
    , testProperty "getSize" prop_GetSize
    , testProperty "readElem" prop_ReadElem
    , testProperty "canModifyElem" prop_CanModifyElem
    , testProperty "writeElem" prop_WriteElem
    , testProperty "modifyElem" prop_ModifyElem

    , testProperty "getIndices" prop_GetIndicesLazy
    , testProperty "getIndices'" prop_GetIndicesStrict
    , testProperty "getElems" prop_GetElemsLazyModifyWith
    , testProperty "getElems'" prop_GetElemsStrictModifyWith
    , testProperty "getAssocs" prop_GetAssocsLazyModifyWith
    , testProperty "getAssocs'" prop_GetAssocsStrictModifyWith

    , testProperty "newZeroVector" prop_NewZeroVector
    , testProperty "setZero" prop_SetZero
    , testProperty "newConstantVector" prop_NewConstantVector
    , testProperty "setConstant" prop_SetConstant
    , testProperty "newBasisVector" prop_NewBasisVector
    , testProperty "setBasisVector" prop_SetBasisVector
    
    , testProperty "newCopyVector" prop_NewCopyVector
    , testProperty "copyVector" prop_CopyVector
    , testProperty "swapVector" prop_SwapVector

    , testProperty "doConj" prop_DoConj
    , testProperty "scaleBy" prop_ScaleBy
    , testProperty "shiftBy" prop_ShiftBy
    , testProperty "modifyWith" prop_ModifyWith
    
    , testProperty "getConjVector" prop_GetConjVector
    , testProperty "getScaledVector" prop_GetScaledVector
    , testProperty "getShiftedVector" prop_GetShiftedVector

    , testProperty "addVector" prop_AddVector
    , testProperty "subVector" prop_SubVector
    , testProperty "axpyVector" prop_AxpyVector
    , testProperty "mulVector" prop_MulVector
    , testProperty "divVector" prop_DivVector
    
    , testProperty "getAddVector" prop_GetAddVector
    , testProperty "getSubVector" prop_GetSubVector
    , testProperty "getMulVector" prop_GetMulVector
    , testProperty "getDivVector" prop_GetDivVector

    , testProperty "getSumAbs" prop_GetSumAbs
    , testProperty "getNorm2" prop_GetNorm2
    , testProperty "getWhichMaxAbs" prop_GetWhichMaxAbs
    , testProperty "getDot" prop_GetDot

    ]
