{- |
Module      :  Numeric.GLS.Tests
Copyright   :  (c) Alberto Ruiz 2014
License     :  BSD3
Maintainer  :  Alberto Ruiz
Stability   :  provisional

Tests for GSL bindings.

-}

module Numeric.GSL.Tests(
    runTests
) where

import Control.Monad(when)
import System.Exit (exitFailure)

import Test.HUnit (runTestTT, failures, Test(..), errors)

import Numeric.LinearAlgebra
import Numeric.GSL
import Numeric.LinearAlgebra.Tests (qCheck, utest)
import Numeric.LinearAlgebra.Tests.Properties ((|~|), (~~))

---------------------------------------------------------------------

fittingTest = utest "levmar" (ok1 && ok2)
    where
    xs = map return [0 .. 39]
    sigma = 0.1
    ys = map return $ toList $ fromList (map (head . expModel [5,0.1,1]) xs)
                    + scalar sigma * (randomVector 0 Gaussian 40)
    dats = zip xs (zip ys (repeat sigma))
    dat = zip xs ys

    expModel [a,lambda,b] [t] = [a * exp (-lambda * t) + b]
    expModelDer [a,lambda,_b] [t] = [[exp (-lambda * t), -t * a * exp(-lambda*t) , 1]]

    sols = fst $ fitModelScaled 1E-4 1E-4 20 (expModel, expModelDer) dats [1,0,0]
    sol = fst $ fitModel 1E-4 1E-4 20 (expModel, expModelDer) dat [1,0,0]

    ok1 = and (zipWith f sols [5,0.1,1]) where f (x,d) r = abs (x-r)<2*d
    ok2 = norm2 (fromList (map fst sols) - fromList sol) < 1E-5

---------------------------------------------------------------------

odeTest = utest "ode" (last (toLists sol) ~~ newsol)
  where
    sol = odeSolveV RK8pd 1E-6 1E-6 0 (l2v $ vanderpol 10) (fromList [1,0]) ts
    ts = linspace 101 (0,100)
    l2v f = \t -> fromList  . f t . toList
    vanderpol mu _t [x,y] = [y, -x + mu * y * (1-x^2) ]
    newsol = [-1.758888036617841,  8.364349410519058e-2]
    -- oldsol = [-1.7588880332411019, 8.364348908711941e-2]

---------------------------------------------------------------------

rootFindingTest = TestList [ utest "root Hybrids" (fst sol1 ~~ [1,1])
                           , utest "root Newton"  (rows (snd sol2) == 2)
                           ]
    where sol1 = root Hybrids 1E-7 30 (rosenbrock 1 10) [-10,-5]
          sol2 = rootJ Newton 1E-7 30 (rosenbrock 1 10) (jacobian 1 10) [-10,-5]
          rosenbrock a b [x,y] = [ a*(1-x), b*(y-x^2) ]
          jacobian a b [x,_y] = [ [-a    , 0]
                                , [-2*b*x, b] ]

---------------------------------------------------------------------

minimizationTest = TestList
    [ utest "minimization conjugatefr" (minim1 f df [5,7] ~~ [1,2])
    , utest "minimization nmsimplex2"  (minim2 f [5,7] `elem` [24,25])
    ]
    where f [x,y] = 10*(x-1)^2 + 20*(y-2)^2 + 30
          df [x,y] = [20*(x-1), 40*(y-2)]
          minim1 g dg ini = fst $ minimizeD ConjugateFR 1E-3 30 1E-2 1E-4 g dg ini
          minim2 g ini = rows $ snd $ minimize NMSimplex2 1E-2 30 [1,1] g ini

---------------------------------------------------------------------

derivTest = abs (d (\x-> x * d (\y-> x+y) 1) 1 - 1) < 1E-10
    where d f x = fst $ derivCentral 0.01 f x

---------------------------------------------------------------------

quad f a b = fst $ integrateQAGS 1E-9 100 f a b

-- A multiple integral can be easily defined using partial application
quad2 f a b g1 g2 = quad h a b
    where h x = quad (f x) (g1 x) (g2 x)

volSphere r = 8 * quad2 (\x y -> sqrt (r*r-x*x-y*y)) 
                        0 r (const 0) (\x->sqrt (r*r-x*x))

---------------------------------------------------------------------

-- besselTest = utest "bessel_J0_e" ( abs (r-expected) < e )
--     where (r,e) = bessel_J0_e 5.0
--           expected = -0.17759677131433830434739701

-- exponentialTest = utest "exp_e10_e" ( abs (v*10^e - expected) < 4E-2 )
--     where (v,e,_err) = exp_e10_e 30.0
--           expected = exp 30.0

--------------------------------------------------------------------

polyEval cs x = foldr (\c ac->ac*x+c) 0 cs

polySolveProp p = length p <2 || last p == 0|| 1E-8 > maximum (map magnitude $ map (polyEval (map (:+0) p)) (polySolve p))


-- | All tests must pass with a maximum dimension of about 20
--  (some tests may fail with bigger sizes due to precision loss).
runTests :: Int  -- ^ maximum dimension
         -> IO ()
runTests n = do
    let test p = qCheck n p
    putStrLn "------ fft"
    test (\v -> ifft (fft v) |~| v)
    c <- runTestTT $ TestList
        [ fittingTest
        , odeTest
        , rootFindingTest
        , minimizationTest
        , utest "deriv" derivTest
        , utest "integrate" (abs (volSphere 2.5 - 4/3*pi*2.5^3) < 1E-8)
        , utest "polySolve" (polySolveProp [1,2,3,4])
        ]
    when (errors c + failures c > 0) exitFailure
    return ()