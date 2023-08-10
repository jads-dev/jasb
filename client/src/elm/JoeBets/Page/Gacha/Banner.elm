module JoeBets.Page.Gacha.Banner exposing
    ( view
    , viewBanners
    , viewCollectionBanner
    , viewCollectionBanners
    )

import AssocList
import Color
import Html exposing (Html)
import Html.Attributes as HtmlA
import JoeBets.Api.Data as Api
import JoeBets.Gacha.Balance as Balance
import JoeBets.Gacha.Balance.Guarantees as Balance
import JoeBets.Gacha.Balance.Rolls as Balance
import JoeBets.Gacha.Banner as Banner exposing (Banner)
import JoeBets.Page.Gacha.Collection.Route as Collection
import JoeBets.Page.Gacha.Model as Gacha
import JoeBets.Page.Gacha.Roll.Model as Roll
import JoeBets.Route as Route
import JoeBets.User.Model as User
import List
import Material.Button as Button
import Util.Html.Attributes as HtmlA
import Util.Maybe as Maybe


type alias Parent a =
    { a
        | gacha : Gacha.Model
    }


viewInternal : Banner.Id -> Banner -> List (Html msg) -> Html msg
viewInternal id { name, description, cover, type_, colors } extra =
    Html.div
        [ HtmlA.class "banner"
        , id |> Banner.cssId |> HtmlA.id
        , HtmlA.customProperties
            [ ( "cover", "url(" ++ cover ++ ")" )
            , ( "background-color", Color.toHexString colors.background )
            , ( "foreground-color", Color.toHexString colors.foreground )
            ]
        ]
        (Html.img [ HtmlA.class "cover", HtmlA.src cover ] []
            :: Html.h2 [ HtmlA.class "title" ] [ Html.text name ]
            :: Html.p [ HtmlA.class "description" ] [ Html.text description ]
            :: Html.div [ HtmlA.class "type" ]
                [ Html.div [] [ Html.text type_, Html.text " Banner" ] ]
            :: extra
        )


view : (Gacha.Msg -> msg) -> Parent a -> ( Banner.Id, Banner ) -> Html msg
view wrap { gacha } ( id, banner ) =
    let
        balance =
            gacha.balance |> Api.dataToMaybe |> Maybe.withDefault Balance.empty

        canRoll amount =
            Balance.compareRolls balance.rolls amount /= LT

        canGuaranteedRoll amount =
            Balance.compareGuarantees balance.guarantees amount /= LT

        rollButton amount =
            let
                amountRolls =
                    Balance.rollsFromInt amount
            in
            Button.filled ("Roll ×" ++ Balance.rollsToString amountRolls)
                |> Button.button
                    (Roll.DoRoll id amountRolls False
                        |> Gacha.RollMsg
                        |> wrap
                        |> Maybe.when (canRoll amountRolls)
                    )
                |> Button.icon Balance.rollIcon
                |> Button.view

        magicRollButton amount =
            let
                amountRolls =
                    Balance.rollsFromInt amount

                amountGuarantees =
                    Balance.guaranteesFromInt amount
            in
            Button.elevated ("Magic ×" ++ Balance.rollsToString amountRolls)
                |> Button.button
                    (Roll.DoRoll id amountRolls True
                        |> Gacha.RollMsg
                        |> wrap
                        |> Maybe.when (canRoll amountRolls && canGuaranteedRoll amountGuarantees)
                    )
                |> Button.icon Balance.rollWithGuaranteeIcon
                |> Button.view

        magicButtons =
            if canGuaranteedRoll (Balance.guaranteesFromInt 1) then
                [ magicRollButton 1
                , magicRollButton 10
                ]

            else
                []
    in
    viewInternal id
        banner
        [ rollButton 1
            :: rollButton 10
            :: magicButtons
            |> Html.div [ HtmlA.class "roll" ]
        ]


viewBanners : (Gacha.Msg -> msg) -> Parent a -> Banner.Banners -> List (Html msg)
viewBanners wrap parent banners =
    [ banners
        |> AssocList.toList
        |> List.map (view wrap parent >> (List.singleton >> Html.li [ HtmlA.class "banner-container" ]))
        |> Html.ol [ HtmlA.class "banners" ]
    ]


viewCollectionBanner : User.Id -> Banner.Id -> Banner -> Html msg
viewCollectionBanner userId bannerId banner =
    Route.a (Collection.Banner bannerId |> Route.CardCollection userId)
        [ HtmlA.class "banner-container" ]
        [ viewInternal bannerId banner [] ]


viewCollectionBanners : User.Id -> Banner.Banners -> Html msg
viewCollectionBanners userId =
    let
        fromTuple ( id, banner ) =
            viewCollectionBanner userId id banner
    in
    AssocList.toList >> List.map fromTuple >> Html.ol [ HtmlA.class "banners" ]
