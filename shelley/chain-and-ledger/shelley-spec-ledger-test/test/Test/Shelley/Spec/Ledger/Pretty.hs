

module Test.Shelley.Spec.Ledger.Pretty where

import Prettyprinter.Util(putDocW)
import Cardano.Ledger.Pretty
import Shelley.Spec.Ledger.TxBody(TxBody)
import Test.Shelley.Spec.Ledger.ConcreteCryptoTypes(C)
import Test.Shelley.Spec.Ledger.Serialisation.Generators ()
import Test.QuickCheck
  ( Arbitrary,
    arbitrary,
    shrink,
    generate,
    Gen,
  )
txbody = (arbitrary :: Gen(TxBody C))

main4 n = do
  b <- generate txbody
  let doc = ppTxBody b
  putDocW n doc
  putStrLn ""