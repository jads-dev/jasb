module Jasb.Page.Gacha.Roll exposing
    ( load
    , onAuthChange
    , update
    , view
    )

import EverySet
import FontAwesome as Icon
import FontAwesome.Solid as Icon
import Html exposing (Html)
import Html.Attributes as HtmlA
import Jasb.Api as Api
import Jasb.Api.Action as Api
import Jasb.Api.Data as Api
import Jasb.Api.IdData as Api
import Jasb.Api.Model as Api
import Jasb.Api.Path as Api
import Jasb.Gacha.Balance.Rolls as Balance
import Jasb.Gacha.Banner as Banner
import Jasb.Material as Material
import Jasb.Messages as Global
import Jasb.Page exposing (Page)
import Jasb.Page.Gacha.Balance as Balance
import Jasb.Page.Gacha.Banner as Banner
import Jasb.Page.Gacha.Card as Card
import Jasb.Page.Gacha.Collection as Collection
import Jasb.Page.Gacha.Collection.Model as Collection
import Jasb.Page.Gacha.Collection.Route as Collection
import Jasb.Page.Gacha.Model as Gacha
import Jasb.Page.Gacha.Roll.Model exposing (..)
import Jasb.Page.Gacha.Route as Gacha
import Jasb.Route as Route
import Jasb.User.Auth.Controls as Auth
import Jasb.User.Auth.Model as Auth
import Jasb.User.Model as User
import Json.Encode as JsonE
import Material.Button as Button
import Time.Model as Time
import Util.AssocList as AssocList


wrapGacha : Gacha.Msg -> Global.Msg
wrapGacha =
    Global.GachaMsg


wrap : Msg -> Global.Msg
wrap =
    Gacha.RollMsg >> wrapGacha


type alias Parent a =
    { a
        | origin : String
        , time : Time.Context
        , auth : Auth.Model
        , gacha : Gacha.Model
        , collection : Collection.Model
    }


onAuthChange : Parent a -> ( Parent a, Cmd Global.Msg )
onAuthChange =
    Balance.load


load : Parent a -> ( Parent a, Cmd Global.Msg )
load oldModel =
    let
        ( { origin, gacha } as model, balanceCmd ) =
            onAuthChange oldModel

        ( banners, bannersCmd ) =
            { path = Api.Gacha (Api.Banners Api.BannersRoot)
            , wrap = Gacha.LoadBanners >> wrapGacha
            , decoder = Banner.bannersDecoder
            }
                |> Api.get origin
                |> Api.getData gacha.banners
    in
    ( { model | gacha = { gacha | banners = banners } }
    , Cmd.batch [ balanceCmd, bannersCmd ]
    )


cardReveal : Parent a -> User.WithId -> Model -> List (Html Global.Msg)
cardReveal _ localUser { banner, progress } =
    let
        attr revealed focus card =
            let
                revealedCard =
                    revealed
                        |> Maybe.map (EverySet.member card)
                        |> Maybe.withDefault True
            in
            [ HtmlA.classList
                [ ( "revealed", revealedCard )
                , ( "unrevealed", not revealedCard )
                , ( "focused", Just card == focus )
                ]
            ]

        ( class, content, after ) =
            case progress of
                Rolling roll ->
                    let
                        button =
                            case roll.cards of
                                Just cards ->
                                    [ Html.div [ HtmlA.class "advance-button" ]
                                        [ Button.filled "Unpack"
                                            |> Button.button (StartRevealing banner cards |> wrap |> Just)
                                            |> Button.view
                                        ]
                                    ]

                                Nothing ->
                                    []
                    in
                    ( "roll"
                    , []
                    , button
                    )

                Revealing { cards, revealed, focus } ->
                    let
                        detailed card =
                            RevealCard card |> wrap
                    in
                    ( "reveal"
                    , [ Card.viewCards (Just detailed) (attr (Just revealed) focus) localUser.id banner cards ]
                    , []
                    )

                Reviewing { cards, focus } ->
                    let
                        detailed card =
                            Gacha.ViewDetailedCard
                                { ownerId = localUser.id, bannerId = banner, cardId = card }
                                Api.Start
                                |> wrapGacha
                    in
                    ( "review"
                    , [ Card.viewCards (Just detailed) (attr Nothing focus) localUser.id banner cards ]
                    , [ Html.div [ HtmlA.class "advance-button" ]
                            [ Button.filled "Done"
                                |> Button.button (FinishRoll |> wrap |> Just)
                                |> Button.view
                            ]
                      ]
                    )
    in
    [ Html.div [ HtmlA.id "roll-screen", HtmlA.class class ]
        (Html.node "fireworks-js"
            [ HtmlA.class "fireworks"
            , HtmlA.style "height" "100%"
            , HtmlA.style "width" "100%"
            ]
            []
            :: List.append content after
        )
    ]


update : Msg -> Parent a -> ( Parent a, Cmd Global.Msg )
update msg ({ origin, gacha } as model) =
    case msg of
        DoRoll banner count guarantee ->
            let
                ( rollAction, cmd ) =
                    { path = Api.Gacha (Api.Roll |> Api.SpecificBanner banner |> Api.Banners)
                    , body =
                        JsonE.object
                            [ ( "count", Balance.encodeRolls count )
                            , ( "guarantee", JsonE.bool guarantee )
                            ]
                    , wrap = LoadRoll banner >> wrap
                    , decoder = rollResultDecoder
                    }
                        |> Api.post origin
                        |> Api.doAction gacha.rollAction
            in
            ( { model
                | gacha =
                    { gacha
                        | rollAction = rollAction
                        , roll =
                            { banner = banner
                            , progress = { cards = Nothing } |> Rolling
                            }
                                |> Just
                    }
              }
            , cmd
            )

        LoadRoll banner response ->
            let
                ( maybeResult, rollAction ) =
                    gacha.rollAction |> Api.handleActionResult response

                updateBalanceResponse old =
                    maybeResult |> Maybe.map .balance |> Maybe.withDefault old

                rollModel { cards } =
                    { banner = banner
                    , progress = { cards = Just cards } |> Rolling
                    }
            in
            ( { model
                | gacha =
                    { gacha
                        | rollAction = rollAction
                        , roll = maybeResult |> Maybe.map rollModel
                        , balance = gacha.balance |> Api.mapData updateBalanceResponse
                    }
              }
            , Cmd.none
            )

        StartRevealing banner cards ->
            let
                roll =
                    { banner = banner
                    , progress =
                        { cards = cards
                        , revealed = EverySet.empty
                        , focus = Nothing
                        }
                            |> Revealing
                    }
            in
            ( { model
                | gacha = { gacha | roll = Just roll }
              }
            , Cmd.none
            )

        RevealCard cardId ->
            let
                progress reveal =
                    let
                        revealed =
                            reveal.revealed |> EverySet.insert cardId
                    in
                    if revealed |> EverySet.diff (AssocList.keySet reveal.cards) |> EverySet.isEmpty then
                        Reviewing { cards = reveal.cards, focus = Just cardId }

                    else
                        Revealing { reveal | revealed = revealed, focus = Just cardId }

                updatedRoll =
                    case gacha.roll of
                        Just roll ->
                            case roll.progress of
                                Revealing reveal ->
                                    Just { roll | progress = progress reveal }

                                _ ->
                                    gacha.roll

                        Nothing ->
                            gacha.roll
            in
            ( { model | gacha = { gacha | roll = updatedRoll } }
            , Cmd.none
            )

        FinishRoll ->
            ( { model | gacha = { gacha | roll = Nothing } }
            , Cmd.none
            )


view : Parent a -> Page Global.Msg
view ({ auth, gacha, collection } as parent) =
    let
        loggedIn =
            case auth.localUser of
                Just localUser ->
                    [ [ Html.ul [ HtmlA.class "collection-links" ]
                            [ Html.li []
                                [ Route.a (Collection.Overview |> Route.CardCollection localUser.id)
                                    []
                                    [ Icon.layerGroup |> Icon.view, Html.text "Your Card Collection" ]
                                ]
                            , Html.li []
                                [ Route.a (Gacha.Forge |> Route.Gacha)
                                    []
                                    [ Icon.hammer |> Icon.view
                                    , Html.text "Forge Cards Of Yourself"
                                    ]
                                ]
                            ]
                      ]
                    , gacha.balance |> Api.viewData Api.viewOrError (Balance.view (Gacha.BalanceMsg >> wrapGacha) parent)
                    , gacha.roll |> Maybe.map (cardReveal parent localUser) |> Maybe.withDefault []
                    ]
                        |> List.concat

                Nothing ->
                    [ Html.p [] [ Auth.logInButton auth "Log in", Html.text " to get cards of your own, or become a card!" ] ]

        editActions =
            if Auth.canManageGacha auth.localUser then
                [ Html.ul [ HtmlA.class "final-actions" ]
                    [ Html.li []
                        [ Button.text "Edit Banners"
                            |> Material.buttonLink Global.ChangeUrl (Gacha.Banner |> Gacha.Edit |> Route.Gacha)
                            |> Button.icon [ Icon.list |> Icon.view ]
                            |> Button.view
                        ]
                    ]
                ]

            else
                []

        contextFromCollection ( _, c ) =
            Collection.manageContext parent.auth collection

        maybeContext =
            collection.overview
                |> Api.idDataToMaybe
                |> Maybe.andThen contextFromCollection
    in
    { title = "Cards"
    , id = "gacha"
    , body =
        [ [ Html.h2 [] [ Html.text "Cards" ] ]
        , loggedIn
        , gacha.banners |> Api.viewData Api.viewOrError (Banner.viewBanners parent)
        , editActions
        , [ Card.viewDetailedCardDialog maybeContext gacha ]
        ]
            |> List.concat
    }
