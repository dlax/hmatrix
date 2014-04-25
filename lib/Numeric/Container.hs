{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE FunctionalDependencies #-}
{-# LANGUAGE UndecidableInstances #-}

-----------------------------------------------------------------------------
-- |
-- Module      :  Numeric.Container
-- Copyright   :  (c) Alberto Ruiz 2010-14
-- License     :  GPL
--
-- Maintainer  :  Alberto Ruiz <aruiz@um.es>
-- Stability   :  provisional
-- Portability :  portable
--
-- Basic numeric operations on 'Vector' and 'Matrix', including conversion routines.
--
-- The 'Container' class is used to define optimized generic functions which work
-- on 'Vector' and 'Matrix' with real or complex elements.
--
-- Some of these functions are also available in the instances of the standard
-- numeric Haskell classes provided by "Numeric.LinearAlgebra".
--
-----------------------------------------------------------------------------

module Numeric.Container (
    -- * Basic functions
    module Data.Packed,
    konst, build,
    constant, linspace,
    diag, ident,
    ctrans,
    -- * Generic operations
    Container(..),
    -- * Matrix product
    Product(..),
    Contraction(..),
    optimiseMult,
    mXm,mXv,vXm,LSDiv(..), cdot, (·), dot, (<.>),
    outer, kronecker,
    -- * Random numbers
    RandDist(..),
    randomVector,
    gaussianSample,
    uniformSample,
    meanCov,
    -- * Element conversion
    Convert(..),
    Complexable(),
    RealElement(),

    RealOf, ComplexOf, SingleOf, DoubleOf,

    IndexOf,
    module Data.Complex,
    -- * IO
    dispf, disps, dispcf, vecdisp, latexFormat, format,
    loadMatrix, saveMatrix, fromFile, fileDimensions,
    readMatrix,
    fscanfVector, fprintfVector, freadVector, fwriteVector,
) where

import Data.Packed
import Data.Packed.Internal(constantD)
import Numeric.ContainerBoot
import Numeric.Chain
import Numeric.IO
import Data.Complex
import Numeric.LinearAlgebra.Algorithms(Field,linearSolveSVD)
import Data.Packed.Random

------------------------------------------------------------------

{- | creates a vector with a given number of equal components:

@> constant 2 7
7 |> [2.0,2.0,2.0,2.0,2.0,2.0,2.0]@
-}
constant :: Element a => a -> Int -> Vector a
-- constant x n = runSTVector (newVector x n)
constant = constantD-- about 2x faster

{- | Creates a real vector containing a range of values:

@\> linspace 5 (-3,7)
5 |> [-3.0,-0.5,2.0,4.5,7.0]@

Logarithmic spacing can be defined as follows:

@logspace n (a,b) = 10 ** linspace n (a,b)@
-}
linspace :: (Enum e, Container Vector e) => Int -> (e, e) -> Vector e
linspace n (a,b) = addConstant a $ scale s $ fromList [0 .. fromIntegral n-1]
    where s = (b-a)/fromIntegral (n-1)

-- | dot product: @cdot u v = 'udot' ('conj' u) v@
cdot :: (Container Vector t, Product t) => Vector t -> Vector t -> t
cdot u v = udot (conj u) v

--------------------------------------------------------

class Contraction a b c | a b -> c, a c -> b, b c -> a
  where
    infixl 7 <>
    -- | matrix-matrix product, matrix-vector product, unconjugated dot product
    (<>) :: a -> b -> c

instance Product t => Contraction (Vector t) (Vector t) t where
    (<>) = udot

instance Product t => Contraction (Matrix t) (Vector t) (Vector t) where
    (<>) = mXv

instance Product t => Contraction (Vector t) (Matrix t) (Vector t) where
    (<>) = vXm

instance Product t => Contraction (Matrix t) (Matrix t) (Matrix t) where
    (<>) = mXm

--------------------------------------------------------

class LSDiv b c | b -> c, c->b where
 infixl 7 <\>
 -- | least squares solution of a linear system, similar to the \\ operator of Matlab\/Octave (based on linearSolveSVD)
 (<\>)  :: Field t => Matrix t -> b t -> c t

instance LSDiv Vector Vector where
    m <\> v = flatten (linearSolveSVD m (reshape 1 v))

instance LSDiv Matrix Matrix where
    (<\>) = linearSolveSVD

--------------------------------------------------------

-- | dot product : @u · v = 'cdot' u v@
--
-- unicode 0x00b7, Alt-Gr .
(·) :: (Container Vector t, Product t) => Vector t -> Vector t -> t
infixl 7 ·
u · v = cdot u v

--------------------------------------------------------------------------------

-- bidirectional type inference
class Konst e d c | d -> c, c -> d
  where
    konst :: e -> d -> c e

instance Container Vector e => Konst e Int Vector
  where
    konst = konst'

instance Container Vector e => Konst e (Int,Int) Matrix
  where
    konst = konst'

--------------------------------------------------------------------------------

class Build d f c e | d -> c, c -> d, f -> e, f -> d, f -> c, c e -> f, d e -> f
  where
    build :: d -> f -> c e

instance Container Vector e => Build Int (e -> e) Vector e
  where
    build = build'

instance Container Matrix e => Build (Int,Int) (e -> e -> e) Matrix e
  where
    build = build'

--------------------------------------------------------------------------------

-- | Compute mean vector and covariance matrix of the rows of a matrix.
meanCov :: Matrix Double -> (Vector Double, Matrix Double)
meanCov x = (med,cov) where
    r    = rows x
    k    = 1 / fromIntegral r
    med  = konst k r `vXm` x
    meds = konst 1 r `outer` med
    xc   = x `sub` meds
    cov  = scale (recip (fromIntegral (r-1))) (trans xc `mXm` xc)

--------------------------------------------------------------------------------

{-# DEPRECATED dot "use udot" #-}
dot :: Product e => Vector e -> Vector e -> e
dot = udot

{-# DEPRECATED (<.>) "use udot or (<>)" #-}
infixl 7 <.>
(<.>) :: Product e => Vector e -> Vector e -> e
(<.>) = udot

