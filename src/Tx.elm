module Tx exposing (..)

import Bytes.Comparable as Bytes
import Cardano exposing (CertificateIntent(..), CredentialWitness(..), SpendSource(..), TxIntent(..), dummyBytes)
import Cardano.Address as Address exposing (Address, Credential(..), NetworkId(..), StakeCredential(..))
import Cardano.Gov as Gov exposing (Id(..))
import Cardano.Value as Value
import Natural exposing (Natural)


intents : Address -> List TxIntent
intents myAddress =
    -- Fill this Tx.intents function with the list of intents needed to satisfy
    -- the Buidler Fest #2 registration constraints: https://buidlerfest.github.io/register/
    -- Namely:
    --  * Send ₳150 to the organizer address
    --  * Delegate to a DRep
    --
    -- The list of existing Tx intents in the elm-cardano library is available at:
    --   https://elm-doc-preview.netlify.app/Cardano?repo=elm-cardano%2Felm-cardano&version=elm-doc-preview#TxIntent
    []



-- Helpers for you, in case you need it.


organizerAddress : Address
organizerAddress =
    -- The address provided by the Buidler Fest #2 as destination for the registration fees
    Address.fromBech32 "addr1zyzpenlg0vywj7zdh9dzdeggaer94zvckfncv9c3886c36yafhxhu32dys6pvn6wlw8dav6cmp4pmtv7cc3yel9uu0nqhcjd29"
        |> Maybe.withDefault blackhole


ada : Float -> Natural
ada amount =
    -- Convert an Ada amount in Float
    -- into a positive integer type (Natural) of Lovelaces
    round (amount * 1000000)
        |> Natural.fromSafeInt


stakeKeyCredentialWitness : Address -> CredentialWitness
stakeKeyCredentialWitness address =
    -- Extract the stake key hash of an address.
    -- If the address doesn’t have a stake credential,
    -- or if the stake credential is a script hash,
    -- this will return a dummy credential witness, which will fail when trying to submit the Tx.
    case Address.extractStakeKeyHash address of
        Just stakeKeyHash ->
            WithKey stakeKeyHash

        Nothing ->
            WithKey (dummyBytes 0 "")


extractDrepCredential : String -> Credential
extractDrepCredential bech32DrepId =
    -- Extract the credentials from a DRep Id provided as a CIP 129 string.
    -- If the DRep Id was invalid, this will return a dummy credential,
    -- which will make the Tx fail when trying to submit.
    case Gov.idFromBech32 bech32DrepId of
        Just (DrepId credential) ->
            credential

        _ ->
            VKeyHash <| dummyBytes 0 ""



-- Helpers for the helpers


blackhole : Address
blackhole =
    -- A fake address to satisfy the compiler for defaults
    Address.base Mainnet (VKeyHash <| dummyBytes 0 "") (VKeyHash <| dummyBytes 0 "")
