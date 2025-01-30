# Elm-cardano template for Buidler Fest #2 registration

This repo serves as a template for anyone willing to try [elm-cardano][elm-cardano]
to build the registration transaction for the Buidler Fest #2 in Vietnam.

The instructions for the registration Tx are available on the [registration page][registration].

[elm-cardano]: https://github.com/elm-cardano/elm-cardano
[registration]: https://buidlerfest.github.io/register/

## Using this elm-cardano template

To help a little bit anyone willing to try elm-cardano, I made a template web app for this.
To compile and start the app locally, do the following:

```sh
# Clone the repo, with the elm-cardano submodule
git clone --recursive https://github.com/mpizenberg/buidlerfest-reg-2.git
cd buidlerfest-reg-2
# Install dependencies and compile the app
npm install && npm run make
# Start the app in watch mode
npm run watch
```

Then all you have to do is follow the registration instructions to fill the `intents` function in the `src/Tx.elm` module:

```elm
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
```

After every file save, the web page web page will update (hot reload).
You just have to click the "Submit registration Tx" button and wait for it to get submitted by your wallet.
