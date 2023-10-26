module JoeBets.Page.Gacha.Banner exposing
    ( viewBanners
    , viewCollectionBanner
    , viewCollectionBanners
    , viewPreviewBanner
    , viewRoll
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
import JoeBets.Route as Route exposing (Route)
import JoeBets.User.Auth.Model as Auth
import JoeBets.User.Model as User
import List
import Material.Button as Button
import Material.IconButton as IconButton
import Util.Html.Attributes as HtmlA
import Util.Maybe as Maybe


type alias Parent a =
    { a
        | auth : Auth.Model
        , gacha : Gacha.Model
    }


viewInternal : Maybe Route -> Banner.Id -> Banner -> List (Html msg) -> Html msg
viewInternal link id { name, description, cover, type_, colors } extra =
    let
        titleWrapper =
            case link of
                Just route ->
                    Route.a route

                Nothing ->
                    Html.div
    in
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
            :: titleWrapper [ HtmlA.class "title" ] [ Html.h3 [] [ Html.text name ] ]
            :: Html.div [ HtmlA.class "description" ] [ Html.p [] [ Html.text description ] ]
            :: Html.div [ HtmlA.class "type" ]
                [ Html.div [] [ Html.text type_, Html.text " Banner" ] ]
            :: extra
        )


viewRoll : Parent a -> ( Banner.Id, Banner ) -> Html Global.Msg
viewRoll { auth, gacha } ( id, banner ) =
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

        buttons =
            if auth.localUser /= Nothing then
                let
                    magicButtons =
                        if canGuaranteedRoll (Balance.guaranteesFromInt 1) then
                            [ magicRollButton 1
                            , magicRollButton 10
                            ]

                        else
                            []
                in
                [ rollButton 1
                    :: rollButton 10
                    :: magicButtons
                    |> Html.div [ HtmlA.class "roll" ]
                , IconButton.filledTonal (Icon.view Icon.eye) "View Possible Cards"
                    |> Material.iconButtonLink Global.ChangeUrl (Gacha.PreviewBanner id |> Route.Gacha)
                    |> IconButton.attrs [ HtmlA.class "preview" ]
                    |> IconButton.view
                ]

            else
                []
    in
    viewInternal
        (Just (Gacha.PreviewBanner id |> Route.Gacha))
        id
        banner
        buttons


viewBanners : Parent a -> Banner.Banners -> List (Html Global.Msg)
viewBanners parent banners =
    let
        viewItem ( id, banner ) =
            [ viewRoll parent ( id, banner ) ]
                |> Html.li []
    in
    [ banners
        |> AssocList.toList
        |> List.map viewItem
        |> Html.ol [ HtmlA.class "banners" ]
    ]


viewPreviewBanner : Banner.Id -> Banner -> Html msg
viewPreviewBanner bannerId banner =
    viewInternal (Just (Gacha.PreviewBanner bannerId |> Route.Gacha)) bannerId banner []


viewCollectionBanner : Bool -> User.Id -> Banner.Id -> Banner -> Html Global.Msg
viewCollectionBanner linkToUser userId bannerId banner =
    let
        route =
            if linkToUser then
                Just (Collection.Banner bannerId |> Route.CardCollection userId)

            else
                Just (Gacha.PreviewBanner bannerId |> Route.Gacha)

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
    viewInternal route bannerId banner possibleButton


viewCollectionBanners : User.Id -> Banner.Banners -> Html Global.Msg
viewCollectionBanners userId =
    let
        fromTuple ( id, banner ) =
            Html.li [] [ viewCollectionBanner True userId id banner ]
    in
    AssocList.toList >> List.map fromTuple >> Html.ol [ HtmlA.class "banners" ]
