module JoeBets.Page.Gacha.Forge exposing
    ( init
    , load
    , onAuthChange
    , update
    , view
    )

import AssocList
import FontAwesome as Icon
import FontAwesome.Solid as Icon
import Html
import Html.Attributes as HtmlA
import JoeBets.Api as Api
import JoeBets.Api.Action as Api
import JoeBets.Api.Data as Api
import JoeBets.Api.Model as Api
import JoeBets.Api.Path as Api
import JoeBets.Editing.Validator as Validator
import JoeBets.Gacha.Balance.Rolls as Balance
import JoeBets.Gacha.Banner as Banner
import JoeBets.Gacha.CardType as CardType
import JoeBets.Gacha.Rarity as Rarity
import JoeBets.Messages as Global
import JoeBets.Page exposing (Page)
import JoeBets.Page.Gacha.Balance as Balance
import JoeBets.Page.Gacha.Card as Card
import JoeBets.Page.Gacha.Collection.Model as Collection
import JoeBets.Page.Gacha.Edit.CardType.RaritySelector as Rarity
import JoeBets.Page.Gacha.Forge.Model exposing (..)
import JoeBets.Page.Gacha.Model as Gacha
import JoeBets.Page.Gacha.Route as Gacha
import JoeBets.Page.Problem.Model as Problem
import JoeBets.Route as Route
import JoeBets.User as User
import JoeBets.User.Auth.Controls as Auth
import JoeBets.User.Auth.Model as Auth
import Json.Decode as JsonD
import Json.Encode as JsonE
import Material.Button as Button
import Material.Dialog as Dialog
import Material.TextField as TextField
import Util.Maybe as Maybe


wrap : Msg -> Global.Msg
wrap =
    Gacha.ForgeMsg >> Global.GachaMsg


type alias Parent a =
    { a
        | origin : String
        , auth : Auth.Model
        , forge : Model
        , problem : Problem.Model
        , route : Route.Route
        , collection : Collection.Model
        , gacha : Gacha.Model
    }


init : Model
init =
    { existing = Api.initData
    , forge = Api.initAction
    , retire = Api.initAction
    , quote = ""
    , rarity = Nothing
    , confirmRetire = Nothing
    }


onAuthChange : Parent a -> ( Parent a, Cmd Global.Msg )
onAuthChange =
    load


load : Parent a -> ( Parent a, Cmd Global.Msg )
load model =
    case model.auth.localUser of
        Just localUser ->
            let
                ( newModel, balanceCmd ) =
                    Balance.load model

                forge =
                    newModel.forge

                ( existing, existingCmd ) =
                    Api.get newModel.origin
                        { path = Api.ForgedCardTypes |> Api.Cards localUser.id |> Api.Gacha
                        , decoder = JsonD.list forgedDecoder
                        , wrap = LoadExisting >> wrap
                        }
                        |> Api.getData forge.existing
            in
            ( { newModel | forge = { forge | existing = existing } }
            , Cmd.batch [ balanceCmd, existingCmd ]
            )

        Nothing ->
            ( Auth.mustBeLoggedIn (Route.Gacha Gacha.Forge) model
            , Cmd.none
            )


update : Msg -> Parent a -> ( Parent a, Cmd Global.Msg )
update msg ({ gacha, forge } as model) =
    case msg of
        SetQuote quote ->
            ( { model | forge = { forge | quote = quote } }, Cmd.none )

        SetRarity rarity ->
            ( { model | forge = { forge | rarity = rarity } }, Cmd.none )

        Forge process ->
            case process of
                Api.Start ->
                    let
                        given localUser rarity =
                            let
                                ( forgeState, cmd ) =
                                    Api.post model.origin
                                        { path = Api.ForgeCardType |> Api.Cards localUser.id |> Api.Gacha
                                        , body =
                                            JsonE.object
                                                [ ( "quote", forge.quote |> JsonE.string )
                                                , ( "rarity", rarity |> Rarity.encodeId )
                                                ]
                                        , decoder = forgeResponseDecoder
                                        , wrap = Api.Finish >> Forge >> wrap
                                        }
                                        |> Api.doAction forge.forge
                            in
                            ( { model | forge = { forge | forge = forgeState } }, cmd )
                    in
                    Maybe.map2 given
                        model.auth.localUser
                        forge.rarity
                        |> Maybe.withDefault ( model, Cmd.none )

                Api.Finish result ->
                    let
                        ( maybeResponse, actionState ) =
                            forge.forge |> Api.handleActionResult result

                        replaceWithNew new old =
                            case old of
                                Forged _ ->
                                    old

                                Unforged ( rarity, _ ) ->
                                    if rarity == Tuple.first new.cardType.rarity then
                                        Forged new

                                    else
                                        old

                        insert existing { forged } =
                            existing |> List.map (replaceWithNew forged)

                        updateExisting existing =
                            maybeResponse
                                |> Maybe.map (insert existing)
                                |> Maybe.withDefault existing

                        updateBalance existing =
                            maybeResponse
                                |> Maybe.map .balance
                                |> Maybe.withDefault existing
                    in
                    ( { model
                        | forge =
                            { forge
                                | forge = actionState
                                , existing = forge.existing |> Api.mapData updateExisting
                            }
                        , gacha =
                            { gacha
                                | balance =
                                    gacha.balance |> Api.mapData updateBalance
                            }
                      }
                    , Cmd.none
                    )

        ConfirmRetire maybeCardTypeId ->
            ( { model | forge = { forge | confirmRetire = maybeCardTypeId } }
            , Cmd.none
            )

        Retire cardTypeId process ->
            case process of
                Api.Start ->
                    let
                        given localUser =
                            let
                                ( retireState, cmd ) =
                                    Api.post model.origin
                                        { path =
                                            Api.RetireForged cardTypeId
                                                |> Api.Cards localUser.id
                                                |> Api.Gacha
                                        , body = JsonE.object []
                                        , decoder = CardType.withIdDecoder
                                        , wrap = Api.Finish >> Retire cardTypeId >> wrap
                                        }
                                        |> Api.doAction forge.retire
                            in
                            ( { model | forge = { forge | retire = retireState } }
                            , cmd
                            )
                    in
                    model.auth.localUser
                        |> Maybe.map given
                        |> Maybe.withDefault ( model, Cmd.none )

                Api.Finish result ->
                    let
                        ( maybeResult, actionState ) =
                            forge.retire |> Api.handleActionResult result

                        remove old =
                            case old of
                                Forged { id, cardType } ->
                                    if id == cardTypeId then
                                        Unforged cardType.rarity

                                    else
                                        old

                                Unforged _ ->
                                    old

                        ( confirmRetire, updateExisting ) =
                            case maybeResult of
                                Just _ ->
                                    ( Nothing, Api.mapData (List.map remove) )

                                Nothing ->
                                    ( forge.confirmRetire, identity )
                    in
                    ( { model
                        | forge =
                            { forge
                                | retire = actionState
                                , existing = forge.existing |> updateExisting
                                , confirmRetire = confirmRetire
                            }
                      }
                    , Cmd.none
                    )

        LoadExisting response ->
            let
                existing =
                    forge.existing |> Api.updateData response
            in
            ( { model | forge = { forge | existing = existing } }, Cmd.none )


view : Parent a -> Page Global.Msg
view ({ auth, forge, gacha } as parent) =
    case auth.localUser of
        Just { user } ->
            let
                forgeRequest =
                    forgeRequestFromModel forge

                isUnforged forged =
                    case forged of
                        Forged _ ->
                            False

                        Unforged _ ->
                            True

                allUnforged =
                    forge.existing
                        |> Api.dataToMaybe
                        |> Maybe.map (List.all isUnforged)
                        |> Maybe.withDefault False

                cost =
                    if allUnforged then
                        Balance.rollsFromInt 0

                    else
                        Balance.rollsFromInt 1

                rolls =
                    gacha.balance
                        |> Api.dataToMaybe
                        |> Maybe.map .rolls
                        |> Maybe.withDefault (Balance.rollsFromInt 0)

                canAfford =
                    Balance.compareRolls rolls cost /= LT

                userInfo =
                    [ Html.div [ HtmlA.class "image" ]
                        [ Html.span [] [ Html.text "Card image: " ]
                        , User.viewAvatar user
                        ]
                    , Html.div [ HtmlA.class "name" ]
                        [ Html.span [] [ Html.text "Card name: " ]
                        , User.viewName user
                        ]
                    , Html.p []
                        [ Html.text "These are based on your discord avatar "
                        , Html.text "and name. "
                        , Html.text "They will not change once the card is "
                        , Html.text "forged. "
                        , Html.text "If they are out of date, then try logging "
                        , Html.text "out and in again. "
                        ]
                    ]

                viewForged forged =
                    case forged of
                        Forged { id, cardType } ->
                            let
                                banner =
                                    Banner.idFromString "jads"

                                onClick =
                                    ConfirmRetire (Just id)
                                        |> wrap
                                        |> Just
                            in
                            Html.li
                                [ cardType.rarity
                                    |> Tuple.first
                                    |> Rarity.class
                                    |> HtmlA.class
                                ]
                                [ Card.viewPlaceholder
                                    onClick
                                    banner
                                    id
                                    cardType
                                ]

                        Unforged ( slug, { name } ) ->
                            Html.li [ slug |> Rarity.class |> HtmlA.class ]
                                [ Html.div [ HtmlA.class "card-outline" ]
                                    [ Html.span []
                                        [ Html.text "No card forged for “"
                                        , Html.text name
                                        , Html.text "” rarity."
                                        ]
                                    ]
                                ]

                freeRarityFromForged forged =
                    case forged of
                        Forged _ ->
                            Nothing

                        Unforged rarity ->
                            Just rarity

                freeRarities =
                    forge.existing
                        |> Api.dataToMaybe
                        |> Maybe.map
                            (List.filterMap freeRarityFromForged
                                >> List.reverse
                                >> AssocList.fromList
                            )
                        |> Maybe.withDefault AssocList.empty

                viewExisting =
                    List.map viewForged >> Html.ol [] >> List.singleton

                confirmRetire =
                    let
                        cancel =
                            ConfirmRetire Nothing |> wrap

                        action cardTypeId =
                            Retire cardTypeId Api.Start
                                |> wrap
                                |> Just
                                |> Api.ifNotWorking forge.retire
                    in
                    [ Dialog.dialog cancel
                        (Html.p []
                            [ Html.text "Are you sure you want to retire this card? "
                            , Html.text "No one will be able to get copies of it in the future. "
                            , Html.text "There is no way to undo this. "
                            , Html.text "You will be able to forge a new card to replace it, if you can afford to."
                            ]
                            :: Api.viewAction [] forge.retire
                        )
                        [ Html.span [ HtmlA.class "cancel" ]
                            [ Button.text "Cancel"
                                |> Button.button (cancel |> Just)
                                |> Button.icon [ Icon.times |> Icon.view ]
                                |> Button.view
                            ]
                        , Button.filled "Retire"
                            |> Button.button (forge.confirmRetire |> Maybe.andThen action)
                            |> Button.icon [ Icon.ban |> Icon.view ]
                            |> Button.attrs [ HtmlA.class "dangerous" ]
                            |> Button.view
                        ]
                        (forge.confirmRetire /= Nothing)
                        |> Dialog.headline [ Html.text "Retire Card" ]
                        |> Dialog.attrs [ HtmlA.id "confirm-retire" ]
                        |> Dialog.view
                    ]
            in
            { title = "Forge Cards"
            , id = "forge"
            , body =
                [ Html.h2 [] [ Html.text "Forge" ]
                , Html.div [ HtmlA.class "explanation" ]
                    [ Html.p []
                        [ Html.text "Forge cards of yourself in the dragon's flame that "
                        , Html.text "others can roll."
                        ]
                    , Html.p []
                        [ Html.text "The first card you create is free, after that it "
                        , Html.text "costs one roll to forge a card."
                        ]
                    , Html.p []
                        [ Html.text "You can retire cards at any time, click on the "
                        , Html.text "card below to retire it."
                        ]
                    , Html.p []
                        [ Html.text "You can have one card of each rarity representing you "
                        , Html.text "active at any time. Retire a card to enable "
                        , Html.text "forging if you already have one for each rarity."
                        ]
                    , Html.p []
                        [ Html.text "You get a self-made copy of cards you forge." ]
                    , Html.p []
                        [ Html.text "Inappropriate cards will result in bans, follow all "
                        , Html.text "JADS rules."
                        ]
                    ]
                , Html.h3 [] [ Html.text "Your Cards" ]
                , Html.div [] confirmRetire
                , forge.existing
                    |> Api.viewData Api.viewOrError viewExisting
                    |> Html.div [ HtmlA.class "existing" ]
                , Html.h3 [] [ Html.text "Forge New Cards" ]
                , gacha.balance
                    |> Api.viewData Api.viewOrError
                        (Balance.view (Gacha.BalanceMsg >> Global.GachaMsg) parent)
                    |> Html.div [ HtmlA.class "balance-wrapper" ]
                , Html.div [ HtmlA.class "tool" ]
                    [ Html.div [ HtmlA.class "set-details" ] userInfo
                    , Html.div [ HtmlA.class "field quote" ]
                        [ TextField.outlined "Quote"
                            (SetQuote >> wrap |> Just |> Api.ifNotWorking forge.forge)
                            forge.quote
                            |> TextField.required True
                            |> TextField.maxLength 100
                            |> TextField.prefixText "“"
                            |> TextField.suffixText "”"
                            |> Validator.textFieldError quoteValidator forge.quote
                            |> TextField.view
                        ]
                    , Html.div [ HtmlA.class "field rarity" ]
                        [ Rarity.selectorFiltered freeRarities
                            (SetRarity >> wrap |> Just |> Api.ifNotWorking forge.forge)
                            forge.rarity
                        ]
                    , Html.div [ HtmlA.class "controls" ]
                        [ Html.span
                            [ HtmlA.classList
                                [ ( "cost", True )
                                , ( "can-afford", canAfford )
                                ]
                            ]
                            [ Balance.viewRolls cost ]
                        , Button.filled "Forge Card"
                            |> Button.button
                                (Api.Start
                                    |> Forge
                                    |> wrap
                                    |> Validator.whenValid forgeRequestValidator forgeRequest
                                    |> Api.ifNotWorking forge.forge
                                    |> Maybe.alsoOnlyIf canAfford
                                )
                            |> Button.icon [ Icon.view Icon.hammer |> Api.orSpinner forge.forge ]
                            |> Button.view
                        ]
                    , Html.div [] (Api.viewAction [] forge.forge)
                    ]
                ]
            }

        Nothing ->
            { title = "Forge Cards"
            , id = "forge"
            , body = []
            }
