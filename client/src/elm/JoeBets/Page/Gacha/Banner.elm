module JoeBets.Page.Gacha.Banner exposing
    ( view
    , viewBanners
    , viewCollectionBanner
    , viewCollectionBanners
    , viewPreviewBanner
    )

import AssocList
import Color
import FontAwesome as Icon
import FontAwesome.Solid as Icon
import Html exposing (Html)
import Html.Attributes as HtmlA
import JoeBets.Api.Data as Api
import JoeBets.Gacha.Balance as Balance
import JoeBets.Gacha.Balance.Guarantees as Balance
import JoeBets.Gacha.Balance.Rolls as Balance
import JoeBets.Gacha.Banner as Banner exposing (Banner)
import JoeBets.Material as Material
import JoeBets.Messages as Global
import JoeBets.Page.Gacha.Collection.Route as Collection
import JoeBets.Page.Gacha.Model as Gacha
import JoeBets.Page.Gacha.Roll.Model as Roll
import JoeBets.Page.Gacha.Route as Gacha
import JoeBets.Route as Route
import JoeBets.User.Model as User
import List
import Material.Button as Button
import Material.IconButton as IconButton
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
            :: Html.div [ HtmlA.class "title" ] [ Html.h3 [] [ Html.text name ] ]
            :: Html.div [ HtmlA.class "description" ] [ Html.p [] [ Html.text description ] ]
            :: Html.div [ HtmlA.class "type" ]
                [ Html.div [] [ Html.text type_, Html.text " Banner" ] ]
            :: extra
        )


view : Parent a -> ( Banner.Id, Banner ) -> Html Global.Msg
view { gacha } ( id, banner ) =
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
                        |> Global.GachaMsg
                        |> Maybe.when (canRoll amountRolls)
                    )
                |> Button.icon [ Balance.rollIcon ]
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
                        |> Global.GachaMsg
                        |> Maybe.when (canRoll amountRolls && canGuaranteedRoll amountGuarantees)
                    )
                |> Button.icon [ Balance.rollWithGuaranteeIcon ]
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
        , IconButton.filledTonal (Icon.view Icon.eye) "View Possible Cards"
            |> Material.iconButtonLink Global.ChangeUrl (Gacha.PreviewBanner id |> Route.Gacha)
            |> IconButton.attrs [ HtmlA.class "preview" ]
            |> IconButton.view
        ]


viewBanners : Parent a -> Banner.Banners -> List (Html Global.Msg)
viewBanners parent banners =
    let
        viewItem ( id, banner ) =
            [ view parent ( id, banner ) ]
                |> Html.li [ HtmlA.class "banner-container" ]
    in
    [ banners
        |> AssocList.toList
        |> List.map viewItem
        |> Html.ol [ HtmlA.class "banners" ]
    ]


viewPreviewBanner : Banner.Id -> Banner -> Html msg
viewPreviewBanner bannerId banner =
    Route.a (Gacha.PreviewBanner bannerId |> Route.Gacha)
        [ HtmlA.class "banner-container" ]
        [ viewInternal bannerId banner [] ]


viewCollectionBanner : Bool -> User.Id -> Banner.Id -> Banner -> Html Global.Msg
viewCollectionBanner linkToUser userId bannerId banner =
    let
        wrapper =
            if linkToUser then
                Route.a (Collection.Banner bannerId |> Route.CardCollection userId)

            else
                Html.div

        possibleButton =
            if not linkToUser then
                [ IconButton.filled (Icon.view Icon.eye) "View Possible Cards"
                    |> Material.iconButtonLink Global.ChangeUrl (Gacha.PreviewBanner bannerId |> Route.Gacha)
                    |> IconButton.attrs [ HtmlA.class "preview" ]
                    |> IconButton.view
                ]

            else
                []
    in
    wrapper
        [ HtmlA.class "banner-container" ]
        [ viewInternal bannerId banner possibleButton ]


viewCollectionBanners : User.Id -> Banner.Banners -> Html Global.Msg
viewCollectionBanners userId =
    let
        fromTuple ( id, banner ) =
            viewCollectionBanner True userId id banner
    in
    AssocList.toList >> List.map fromTuple >> Html.ol [ HtmlA.class "banners" ]
