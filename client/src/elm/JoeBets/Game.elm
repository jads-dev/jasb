module JoeBets.Game exposing
    ( view
    , viewMods
    )

import AssocList
import EverySet
import FontAwesome as Icon
import FontAwesome.Regular as OutlineIcon
import FontAwesome.Solid as Icon
import Html exposing (Html)
import Html.Attributes as HtmlA
import JoeBets.Coins as Coins
import JoeBets.Game.Details as Game
import JoeBets.Game.Id as Game
import JoeBets.Game.Model as Game exposing (Game)
import JoeBets.Page.Bets.Model as Bets
import JoeBets.Page.Edit.Model as Edit
import JoeBets.Route as Route
import JoeBets.User as User
import JoeBets.User.Auth.Model as Auth
import JoeBets.User.Model as User
import Material.IconButton as IconButton
import Time.Date as Date
import Time.Model as Time
import Util.String as String


viewMods : Game.Details -> Html msg
viewMods { mods } =
    let
        renderMod ( userId, user ) =
            Html.li [] [ User.viewLink User.Full userId user ]

        modsContent =
            if AssocList.isEmpty mods then
                [ Html.span [] [ Html.text "No bet managers for this game." ]
                ]

            else
                [ Html.span [] [ Html.text "Bet managers for this game:" ]
                , mods |> AssocList.toList |> List.map renderMod |> Html.ul []
                ]
    in
    Html.span [ HtmlA.class "bet-managers" ] modsContent


view : (Bets.Msg -> msg) -> Bets.Model -> Time.Context -> Maybe User.WithId -> Game.Id -> Game -> Maybe Game.Details -> Html msg
view wrap { favourites } time localUser id { name, cover, bets, progress } details =
    let
        progressView =
            case progress of
                Game.Future _ ->
                    [ Html.text "Future Game" ]

                Game.Current { start } ->
                    Date.viewInTense time Time.Absolute { future = "Starts", past = "Started" } start

                Game.Finished { start, finish } ->
                    [ Date.viewInTense time Time.Absolute { future = "Starts", past = "Started" } start
                    , [ Html.text ", " ]
                    , Date.viewInTense time Time.Absolute { future = "Finishes", past = "Finished" } finish
                    ]
                        |> List.concat

        renderDetails { staked } =
            [ Html.span [ HtmlA.class "total-staked" ] [ staked |> Coins.view, Html.text " bet in " ] ]

        stakedDetails =
            details |> Maybe.map renderDetails |> Maybe.withDefault []

        normalContent =
            [ Html.img
                [ HtmlA.class "cover"
                , HtmlA.src cover
                , HtmlA.alt ""
                ]
                []
            , Html.div [ HtmlA.class "details" ]
                [ Html.h2
                    [ HtmlA.class "title permalink" ]
                    [ Html.text name, Icon.link |> Icon.view ]
                , [ stakedDetails
                  , [ Html.span [ HtmlA.class "bet-count" ]
                        [ bets |> String.fromInt |> Html.text
                        , Html.text " bet"
                        , bets |> String.plural |> Html.text
                        , Html.text "."
                        ]
                    ]
                  ]
                    |> List.concat
                    |> Html.span []
                , Html.span
                    [ HtmlA.class "progress" ]
                    progressView
                ]
            ]

        adminContent =
            if localUser |> Auth.isMod id then
                [ Html.div [ HtmlA.class "admin-controls" ]
                    [ Route.a (id |> Just |> Edit.Game |> Route.Edit) [] [ Icon.pen |> Icon.view ]
                    ]
                ]

            else
                []

        isFavourite =
            favourites.value |> EverySet.member id

        favouriteControl =
            let
                ( icon, action ) =
                    if isFavourite then
                        ( Icon.star, False )

                    else
                        ( OutlineIcon.star, True )
            in
            Html.div [ HtmlA.class "favourite-control" ]
                [ IconButton.view (icon |> Icon.view)
                    "Favourite"
                    (action |> Bets.SetFavourite id |> wrap |> Just)
                ]

        interactions =
            Html.div [ HtmlA.class "interactions" ] (favouriteControl :: adminContent)
    in
    [ Route.a (Route.Bets Bets.Active id) [] [ normalContent |> Html.div [] ]
    , interactions
    ]
        |> Html.div
            [ HtmlA.classList [ ( "game", True ), ( "favourite", isFavourite ) ]
            , HtmlA.attribute "style" ("--cover: url(" ++ cover ++ ")")
            ]
