port module Main exposing (..)

import Browser
import Bytes.Comparable as Bytes exposing (Bytes)
import Cardano
import Cardano.Address as Address exposing (Address)
import Cardano.Cip30 as Cip30
import Cardano.Transaction as Transaction exposing (Transaction)
import Cardano.TxExamples exposing (prettyTx)
import Cardano.Utxo as Utxo exposing (Output, OutputReference, TransactionId)
import Html exposing (Html, button, div, text)
import Html.Attributes exposing (height, src)
import Html.Events exposing (onClick)
import Json.Decode as JDecode exposing (Value)
import Tx


main =
    -- The main entry point of our app
    -- More info about that in the Browser package docs:
    -- https://package.elm-lang.org/packages/elm/browser/latest/
    Browser.element
        { init = init
        , update = update
        , subscriptions = \_ -> fromWallet WalletMsg
        , view = view
        }


port toWallet : Value -> Cmd msg


port fromWallet : (Value -> msg) -> Sub msg


type Msg
    = WalletMsg Value
    | ConnectButtonClicked { id : String }
    | SubmitTx



-- MODEL


type Model
    = Startup
    | WalletDiscovered (List Cip30.WalletDescriptor)
    | WalletLoading
        { wallet : Cip30.Wallet
        , utxos : List ( OutputReference, Output )
        }
    | WalletLoaded
        { wallet : Cip30.Wallet
        , utxos : List ( OutputReference, Output )
        , changeAddress : Address
        , error : Maybe String
        }
    | TxSubmitted (Bytes TransactionId)


init : () -> ( Model, Cmd Msg )
init _ =
    ( Startup
    , toWallet <| Cip30.encodeRequest Cip30.discoverWallets
    )



-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case ( msg, model ) of
        ( WalletMsg value, _ ) ->
            case ( JDecode.decodeValue Cip30.responseDecoder value, model ) of
                -- We just discovered available wallets
                ( Ok (Cip30.AvailableWallets wallets), Startup ) ->
                    ( WalletDiscovered wallets, Cmd.none )

                -- We just connected to the wallet, let’s ask for the available utxos
                ( Ok (Cip30.EnabledWallet wallet), WalletDiscovered _ ) ->
                    ( WalletLoading { wallet = wallet, utxos = [] }
                    , toWallet <| Cip30.encodeRequest <| Cip30.getUtxos wallet { amount = Nothing, paginate = Nothing }
                    )

                -- We just received the utxos, let’s ask for the main change address of the wallet
                ( Ok (Cip30.ApiResponse { walletId } (Cip30.WalletUtxos utxos)), WalletLoading { wallet } ) ->
                    ( WalletLoading { wallet = wallet, utxos = utxos }
                    , toWallet (Cip30.encodeRequest (Cip30.getChangeAddress wallet))
                    )

                ( Ok (Cip30.ApiResponse { walletId } (Cip30.ChangeAddress address)), WalletLoading { wallet, utxos } ) ->
                    ( WalletLoaded { wallet = wallet, utxos = utxos, changeAddress = address, error = Nothing }
                    , Cmd.none
                    )

                ( Ok (Cip30.ApiResponse _ (Cip30.SignedTx vkeywitnesses)), WalletLoaded ({ wallet, utxos } as loadedWallet) ) ->
                    let
                        txToSubmit =
                            Cardano.finalize (Utxo.refDictFromList utxos) [] (Tx.intents loadedWallet.changeAddress)
                                |> Result.map .tx
                    in
                    case txToSubmit of
                        Err buildError ->
                            ( WalletLoaded { loadedWallet | error = Just <| Debug.toString buildError }
                            , Cmd.none
                            )

                        Ok tx ->
                            let
                                -- Update the signatures of the Tx with the wallet response
                                signedTx =
                                    Transaction.updateSignatures (Just << List.append vkeywitnesses << Maybe.withDefault []) tx
                            in
                            ( model
                            , toWallet (Cip30.encodeRequest (Cip30.submitTx wallet signedTx))
                            )

                ( Ok (Cip30.ApiResponse { walletId } (Cip30.SubmittedTx txId)), WalletLoaded _ ) ->
                    ( TxSubmitted txId, Cmd.none )

                ( Ok (Cip30.ApiResponse _ _), WalletLoaded loadedWallet ) ->
                    ( WalletLoaded { loadedWallet | error = Just "TODO: unhandled CIP30 response yet" }
                    , Cmd.none
                    )

                -- Received an error message from the wallet
                ( Ok (Cip30.ApiError { info }), WalletLoaded loadedWallet ) ->
                    ( WalletLoaded { loadedWallet | error = Just info }
                    , Cmd.none
                    )

                -- Unknown type of message received from the wallet
                ( Ok (Cip30.UnhandledResponseType error), WalletLoaded loadedWallet ) ->
                    ( WalletLoaded { loadedWallet | error = Just error }
                    , Cmd.none
                    )

                _ ->
                    ( model, Cmd.none )

        ( ConnectButtonClicked { id }, WalletDiscovered descriptors ) ->
            ( model, toWallet (Cip30.encodeRequest (Cip30.enableWallet { id = id, extensions = [] })) )

        ( SubmitTx, WalletLoaded ({ wallet, utxos } as loadedWallet) ) ->
            let
                txToSubmit =
                    Cardano.finalize (Utxo.refDictFromList utxos) [] (Tx.intents loadedWallet.changeAddress)
                        |> Result.map .tx
            in
            case txToSubmit of
                Err buildError ->
                    ( WalletLoaded { loadedWallet | error = Just <| Debug.toString buildError }
                    , Cmd.none
                    )

                Ok tx ->
                    ( WalletLoaded { loadedWallet | error = Nothing }
                    , toWallet (Cip30.encodeRequest (Cip30.signTx wallet { partialSign = True } tx))
                    )

        _ ->
            ( model, Cmd.none )



-- VIEW


view : Model -> Html Msg
view model =
    case model of
        Startup ->
            Html.h3 [] [ text "Buidler Fest #2 Registration" ]

        WalletDiscovered availableWallets ->
            div []
                [ Html.h3 [] [ text "Buidler Fest #2 Registration" ]
                , Html.p [] [ text "CIP-30 wallets detected:" ]
                , viewAvailableWallets availableWallets
                ]

        WalletLoading _ ->
            div []
                [ Html.h3 [] [ text "Buidler Fest #2 Registration" ]
                , Html.p [] [ text "Loading wallet assets ..." ]
                ]

        WalletLoaded { wallet, utxos, changeAddress, error } ->
            let
                txToSubmit =
                    Cardano.finalize (Utxo.refDictFromList utxos) [] (Tx.intents changeAddress)
                        |> Result.map .tx
            in
            div []
                [ Html.h3 [] [ text "Buidler Fest #2 Registration" ]
                , Html.p [] [ text <| "Wallet: " ++ (Cip30.walletDescriptor wallet).name ]
                , Html.p [] [ text <| "My address: " ++ Address.toBech32 changeAddress ]
                , Html.p [] [ text <| "Organizer address: addr1zyzpenlg0vywj7zdh9dzdeggaer94zvckfncv9c3886c36yafhxhu32dys6pvn6wlw8dav6cmp4pmtv7cc3yel9uu0nqhcjd29" ]
                , case txToSubmit of
                    Err err ->
                        Html.p [] [ text <| "Invalid Tx intents: " ++ Debug.toString err ]

                    Ok tx ->
                        div []
                            [ Html.p [] [ text "Tx to submit:" ]
                            , Html.pre [] [ text <| prettyTx tx ]
                            ]
                , Html.p [] [ button [ onClick SubmitTx ] [ text "Submit registration Tx" ] ]
                , case error of
                    Nothing ->
                        text ""

                    Just err ->
                        div [] [ text <| "Error: " ++ err ]
                ]

        TxSubmitted txId ->
            div [] [ text <| "Tx submitted: " ++ Bytes.toHex txId ]


viewAvailableWallets : List Cip30.WalletDescriptor -> Html Msg
viewAvailableWallets wallets =
    let
        walletDescription : Cip30.WalletDescriptor -> String
        walletDescription w =
            "id: " ++ w.id ++ ", name: " ++ w.name

        walletIcon : Cip30.WalletDescriptor -> Html Msg
        walletIcon { icon } =
            Html.img [ src icon, height 32 ] []

        connectButton { id } =
            Html.button [ onClick (ConnectButtonClicked { id = id }) ] [ text "connect" ]

        walletRow w =
            Html.p [] [ walletIcon w, text (walletDescription w), connectButton w ]
    in
    div [] (List.map walletRow wallets)
