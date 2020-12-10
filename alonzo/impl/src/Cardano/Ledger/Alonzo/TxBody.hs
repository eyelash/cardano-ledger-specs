{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE DerivingVia #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE PatternSynonyms #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE StandaloneDeriving #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE ConstraintKinds #-}


module Cardano.Ledger.Alonzo.TxBody
  ( IsFee (..),
    TxIn (..),
    TxOut (..),
    TxBody
      ( TxBody,
        inputs,
        outputs,
        certs,
        wdrls,
        txfee,
        vldt,
        update,
        adHash,
        mint,
        exunits,
        scriptHash
      ),
  )
where

import Prelude hiding (lookup)
import Cardano.Binary (FromCBOR (..), ToCBOR (..))
import Cardano.Ledger.Alonzo.Data (DataHash)
import Cardano.Ledger.Alonzo.Scripts (ExUnits)
import qualified Cardano.Ledger.Alonzo.Scripts as AlonzoScript(Tag(..))
import Cardano.Ledger.Alonzo.TxWitness (ScriptDataHash, RdmrPtr(..))
import Cardano.Ledger.AuxiliaryData (AuxiliaryDataHash)
import Cardano.Ledger.Compactible
import qualified Cardano.Ledger.Core as Core
import qualified Cardano.Ledger.Crypto as CC
import Cardano.Ledger.Era (Crypto, Era)
import Cardano.Ledger.Mary.Value (Value(..),PolicyID,AssetName,lookup)
import Cardano.Ledger.ShelleyMA.Timelocks (ValidityInterval (..))
import Cardano.Ledger.Val
  ( DecodeMint,
    DecodeNonNegative,
    EncodeMint,
    Val,
    decodeMint,
    decodeNonNegative,
    encodeMint,
    isZero,
  )
import Control.DeepSeq (NFData)
import Data.Coders
import Data.MemoBytes (Mem, MemoBytes (..), memoBytes)
import Data.Sequence.Strict (StrictSeq)
import qualified Data.Sequence.Strict as StrictSeq
import Data.Set (Set)
import qualified Data.Set as Set
import qualified Data.Map as Map(Map,findIndex,elemAt)
import Data.Typeable (Typeable)
import Data.Word (Word64)
import GHC.Generics (Generic)
import NoThunks.Class (InspectHeapNamed (..), NoThunks)
import Shelley.Spec.Ledger.Address(RewardAcnt)
import Shelley.Spec.Ledger.BaseTypes (StrictMaybe (..))
import Shelley.Spec.Ledger.Coin (Coin)
import Shelley.Spec.Ledger.CompactAddr (CompactAddr)
import Shelley.Spec.Ledger.Delegation.Certificates (DCert)
import Shelley.Spec.Ledger.Hashing
import Shelley.Spec.Ledger.PParams (Update)
import Shelley.Spec.Ledger.TxBody (TxId, Wdrl (Wdrl), unWdrl)

-- | Tag indicating whether an input should be used to pay transaction fees.
-- This is used to prevent the entirety of a script's inputs being used for fees
-- in the case that the script fails to validate.
newtype IsFee = IsFee Bool
  deriving
    ( Eq,
      NFData,
      NoThunks,
      Ord,
      Show,
      Typeable,
      ToCBOR,
      FromCBOR
    )

-- | Input of a UTxO. This references the transaction being spent from and the
-- index of the output being spent, as well as a tag indicating whether this
-- input should be used as a fee.
data TxIn crypto
  = TxInCompact
      {-# UNPACK #-} !(TxId crypto)
      {-# UNPACK #-} !Word64
      !IsFee
  deriving (Generic)

deriving instance Ord (TxIn crypto)

deriving instance Eq (TxIn crypto)

deriving instance Show (TxIn crypto)

instance CC.Crypto crypto => NFData (TxIn crypto)

instance NoThunks (TxIn crypto)

data TxOut era
  = TxOutCompact
      {-# UNPACK #-} !(CompactAddr (Crypto era))
      !(CompactForm (Core.Value era))
      !(StrictMaybe (DataHash era))
  deriving (Generic)

deriving stock instance
  ( Eq (Core.Value era),
    Eq (CompactForm (Core.Value era))
  ) =>
  Eq (TxOut era)

instance
  ( Show (Value era),
    Show (CompactForm (Core.Value era))
  ) =>
  Show (TxOut era)
  where
  show = error "Not yet implemented"

deriving via InspectHeapNamed "TxOut" (TxOut era) instance NoThunks (TxOut era)

data TxBodyRaw era = TxBodyRaw
  { _inputs :: !(Set (TxIn (Crypto era))),
    _outputs :: !(StrictSeq (TxOut era)),
    _certs :: !(StrictSeq (DCert (Crypto era))),
    _wdrls :: !(Wdrl (Crypto era)),
    _txfee :: !Coin,
    _vldt :: !ValidityInterval,
    _update :: !(StrictMaybe (Update era)),
    _adHash :: !(StrictMaybe (AuxiliaryDataHash (Crypto era))),
    _mint :: !(Core.Value era),
    _exunits :: !ExUnits,
    _scriptHash :: !(StrictMaybe (ScriptDataHash (Crypto era)))
  }
  deriving (Generic, Typeable)

deriving instance
  ( Eq (Core.Value era),
    Eq (CompactForm (Core.Value era))
  ) =>
  Eq (TxBodyRaw era)

instance
  (Typeable era, NoThunks (Core.Value era)) =>
  NoThunks (TxBodyRaw era)

deriving instance
  (Era era, Show (Core.Value era), Show (CompactForm (Core.Value era))) =>
  Show (TxBodyRaw era)

newtype TxBody era = TxBodyConstr (MemoBytes (TxBodyRaw era))
  deriving (ToCBOR)

deriving newtype instance
  ( Eq (Core.Value era),
    Eq (CompactForm (Core.Value era))
  ) =>
  Eq (TxBody era)

deriving instance
  (Typeable era, NoThunks (Core.Value era)) =>
  NoThunks (TxBody era)

deriving instance
  ( Era era,
    Compactible (Core.Value era),
    Show (CompactForm (Core.Value era)),
    Show (Core.Value era)
  ) =>
  Show (TxBody era)

deriving via
  (Mem (TxBodyRaw era))
  instance
    ( Era era,
      Typeable (Core.Script era),
      Typeable (Core.AuxiliaryData era),
      Val (Core.Value era),
      Compactible (Core.Value era),
      Show (Core.Value era),
      DecodeNonNegative (Core.Value era),
      DecodeMint (Core.Value era),
      FromCBOR (Annotator (Core.Script era))
    ) =>
    FromCBOR (Annotator (TxBody era))


type AlonzoBody era =
   ( Era era,
    Typeable (Core.AuxiliaryData era),
    Typeable (Core.Script era),
    ToCBOR (CompactForm (Core.Value era)),
    ToCBOR (Core.Script era),
    EncodeMint (Core.Value era),
    Val (Core.Value era)
  )

pattern TxBody :: AlonzoBody era =>
  Set (TxIn (Crypto era)) ->
  StrictSeq (TxOut era) ->
  StrictSeq (DCert (Crypto era)) ->
  Wdrl (Crypto era) ->
  Coin ->
  ValidityInterval ->
  StrictMaybe (Update era) ->
  StrictMaybe (AuxiliaryDataHash (Crypto era)) ->
  Core.Value era ->
  ExUnits ->
  StrictMaybe (ScriptDataHash (Crypto era)) ->
  TxBody era
pattern TxBody
  { inputs,
    outputs,
    certs,
    wdrls,
    txfee,
    vldt,
    update,
    adHash,
    mint,
    exunits,
    scriptHash
  } <-
  TxBodyConstr
    ( Memo
        TxBodyRaw
          { _inputs = inputs,
            _outputs = outputs,
            _certs = certs,
            _wdrls = wdrls,
            _txfee = txfee,
            _vldt = vldt,
            _update = update,
            _adHash = adHash,
            _mint = mint,
            _exunits = exunits,
            _scriptHash = scriptHash
          }
        _
      )
  where
    TxBody
      inputs
      outputs
      certs
      wdrls
      txfee
      vldt
      update
      adHash
      mint
      exunits
      scriptHash =
        TxBodyConstr $
          memoBytes
            ( encodeTxBodyRaw $
                TxBodyRaw
                  inputs
                  outputs
                  certs
                  wdrls
                  txfee
                  vldt
                  update
                  adHash
                  mint
                  exunits
                  scriptHash
            )

{-# COMPLETE TxBody #-}

instance Era era => HashAnnotated (TxBody era) era where
  type HashIndex (TxBody era) = EraIndependentTxBody

--------------------------------------------------------------------------------
-- Serialisation
--------------------------------------------------------------------------------

instance CC.Crypto crypto => ToCBOR (TxIn crypto) where
  toCBOR (TxInCompact txId idx isFee) =
    encode $
      Rec TxInCompact
        !> To txId
        !> To idx
        !> To isFee

instance CC.Crypto crypto => FromCBOR (TxIn crypto) where
  fromCBOR = decode $ RecD TxInCompact <! From <! From <! From

instance
  (Era era, ToCBOR (CompactForm (Core.Value era))) =>
  ToCBOR (TxOut era)
  where
  toCBOR (TxOutCompact addr cv dh) =
    encode $
      Rec TxOutCompact !> To addr !> To cv !> To dh

instance
  ( Era era,
    DecodeNonNegative (CompactForm (Core.Value era)),
    Compactible (Core.Value era)
  ) =>
  FromCBOR (TxOut era)
  where
  fromCBOR =
    decode $
      RecD TxOutCompact
        <! From
        <! D decodeNonNegative
        <! From

encodeTxBodyRaw ::
  ( Era era,
    EncodeMint (Core.Value era),
    Val (Core.Value era),
    Typeable (Core.AuxiliaryData era),
    Typeable (Core.Script era),
    ToCBOR (CompactForm (Core.Value era)),
    ToCBOR (Core.Script era)
  ) =>
  TxBodyRaw era ->
  Encode ('Closed 'Sparse) (TxBodyRaw era)
encodeTxBodyRaw
  TxBodyRaw
    { _inputs,
      _outputs,
      _certs,
      _wdrls,
      _txfee,
      _vldt = ValidityInterval bot top,
      _update,
      _adHash,
      _mint,
      _exunits,
      _scriptHash
    } =
    Keyed
      ( \i o f t c w u mh b mi e s ->
          TxBodyRaw i o c w f (ValidityInterval b t) u mh mi e s
      )
      !> Key 0 (E encodeFoldable _inputs)
      !> Key 1 (E encodeFoldable _outputs)
      !> Key 2 (To _txfee)
      !> encodeKeyedStrictMaybe 3 top
      !> Omit null (Key 4 (E encodeFoldable _certs))
      !> Omit (null . unWdrl) (Key 5 (To _wdrls))
      !> encodeKeyedStrictMaybe 6 _update
      !> encodeKeyedStrictMaybe 7 _adHash
      !> encodeKeyedStrictMaybe 8 bot
      !> Omit isZero (Key 9 (E encodeMint _mint))
      !> Omit (== mempty) (Key 10 (To _exunits))
      !> encodeKeyedStrictMaybe 11 _scriptHash
    where
      encodeKeyedStrictMaybe key x =
        Omit isSNothing (Key key (E (toCBOR . fromSJust) x))

      isSNothing :: StrictMaybe a -> Bool
      isSNothing SNothing = True
      isSNothing _ = False

      fromSJust :: StrictMaybe a -> a
      fromSJust (SJust x) = x
      fromSJust SNothing = error "SNothing in fromSJust"

instance
  forall era.
  ( Era era,
    Typeable (Core.Script era),
    Typeable (Core.AuxiliaryData era),
    Val (Core.Value era),
    Compactible (Core.Value era),
    Show (Core.Value era),
    DecodeNonNegative (Core.Value era),
    DecodeMint (Core.Value era),
    FromCBOR (Annotator (Core.Script era))
  ) =>
  FromCBOR (TxBodyRaw era)
  where
  fromCBOR = decode $ SparseKeyed "TxBodyRaw" init bodyFields requiredFields
    where
      init :: TxBodyRaw era
      init =
        TxBodyRaw
          mempty
          StrictSeq.empty
          StrictSeq.empty
          (Wdrl mempty)
          mempty
          (ValidityInterval SNothing SNothing)
          SNothing
          SNothing
          mempty
          mempty
          SNothing
      bodyFields 0 =
        field
          (\x tx -> tx {_inputs = x})
          (D (decodeSet fromCBOR))
      bodyFields 1 =
        field
          (\x tx -> tx {_outputs = x})
          (D (decodeStrictSeq fromCBOR))
      bodyFields 2 = field (\x tx -> tx {_txfee = x}) From
      bodyFields 3 =
        field
          (\x tx -> tx {_vldt = (_vldt tx) {invalidHereafter = x}})
          (D (SJust <$> fromCBOR))
      bodyFields 4 =
        field
          (\x tx -> tx {_certs = x})
          (D (decodeStrictSeq fromCBOR))
      bodyFields 5 = field (\x tx -> tx {_wdrls = x}) From
      bodyFields 6 = field (\x tx -> tx {_update = x}) (D (SJust <$> fromCBOR))
      bodyFields 7 = field (\x tx -> tx {_adHash = x}) (D (SJust <$> fromCBOR))
      bodyFields 8 =
        field
          (\x tx -> tx {_vldt = (_vldt tx) {invalidBefore = x}})
          (D (SJust <$> fromCBOR))
      bodyFields 9 = field (\x tx -> tx {_mint = x}) (D decodeMint)
      bodyFields 10 = field (\x tx -> tx {_exunits = x}) From
      bodyFields 11 =
        field
          (\x tx -> tx {_scriptHash = x})
          (D (SJust <$> fromCBOR))
      bodyFields n = field (\_ t -> t) (Invalid n)
      requiredFields =
        [ (0, "inputs"),
          (1, "outputs"),
          (2, "fee")
        ]

instance
  ( Era era,
    Typeable (Core.Script era),
    Typeable (Core.AuxiliaryData era),
    Val (Core.Value era),
    Compactible (Core.Value era),
    Show (Core.Value era),
    DecodeNonNegative (Core.Value era),
    DecodeMint (Core.Value era),
    FromCBOR (Annotator (Core.Script era))
  ) =>
  FromCBOR (Annotator (TxBodyRaw era))
  where
  fromCBOR = pure <$> fromCBOR


-- ===========================================

data ScriptPurpose crypto
   = Minting !(PolicyID crypto)
   | Spending !(TxIn crypto)
   | Rewarding !(RewardAcnt crypto)   -- Not sure if this is the right type.
   | Certifying !(DCert crypto)


txins :: AlonzoBody era => TxBody era -> Set (TxId (Crypto era), Word64)
txins (TxBody{inputs = is}) = Set.foldl' accum Set.empty is
  where accum ans (TxInCompact id index _) = Set.insert (id,index) ans

txinputs_vf :: AlonzoBody era => TxBody era -> Set (TxId (Crypto era), Word64)
txinputs_vf (TxBody{inputs = is}) = Set.foldl' accum Set.empty is
  where accum ans (TxInCompact id index (IsFee True)) = Set.insert (id,index) ans
        accum ans _ = ans

class Indexable elem container where
   indexOf :: elem -> container -> Word64
   atIndex :: Word64 -> container -> elem

instance Ord k => Indexable k (Set k) where
   indexOf n set = fromIntegral $ Set.findIndex n set
   atIndex i set = Set.elemAt (fromIntegral i) set

instance Eq k => Indexable k (StrictSeq k) where
   indexOf n seq = case StrictSeq.findIndexL (==n) seq of
      Just n -> fromIntegral n
      Nothing -> error("Not found in StrictSeq")
   atIndex i seq = case StrictSeq.lookup (fromIntegral i) seq of
      Just elem -> elem
      Nothing -> error ("No elem at index "++show i)

instance Ord k => Indexable k (Map.Map k v) where
   indexOf n mp = fromIntegral $ Map.findIndex n mp
   atIndex i mp = fst(Map.elemAt (fromIntegral i) mp)  -- If one needs the value, on can use Map.Lookup

toRdmrPtrFromBody ::
  ( AlonzoBody era, Core.Value era ~ Value (Crypto era) )
  =>  TxBody era -> ScriptPurpose (Crypto era) -> RdmrPtr
toRdmrPtrFromBody txbody (Minting pid) =  RdmrPtr AlonzoScript.Mint (indexOf pid (getMapFromValue(mint txbody)))
toRdmrPtrFromBody txbody (Spending txin) =  RdmrPtr AlonzoScript.Spend (indexOf txin (inputs txbody))
toRdmrPtrFromBody txbody (Rewarding racnt) = RdmrPtr AlonzoScript.Rewrd (indexOf racnt (unWdrl(wdrls txbody)))
toRdmrPtrFromBody txbody (Certifying d) = RdmrPtr AlonzoScript.Cert (indexOf d (certs txbody))

getMapFromValue:: Value crypto -> Map.Map (PolicyID crypto) (Map.Map AssetName Integer)
getMapFromValue (Value _ m) = m
