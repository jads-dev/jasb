module Jasb.Game exposing
    ( view
    , viewManagers
    )

import AssocList
import EverySet
import FontAwesome as Icon
import FontAwesome.Regular as OutlineIcon
import FontAwesome.Solid as Icon
import Html exposing (Html)
import Html.Attributes as HtmlA
import Jasb.Coins as Coins
import Jasb.Game.Id as Game
import Jasb.Game.Model as Game exposing (Game)
import Jasb.Material as Material
import Jasb.Page.Bets.Model as Bets
import Jasb.Page.Edit.Model as Edit
import Jasb.Route as Route exposing (Route)
import Jasb.Sentiment as Sentiment
import Jasb.User as User
import Jasb.User.Auth.Model as Auth
import Jasb.User.Model as User
import Material.IconButton as IconButton
import Time.Date as Date
import Time.Model as Time
import Util.String as String


viewManagers : Game -> Html msg
viewManagers { managers } =
    let
        renderManager ( userId, user ) =
            Html.li [] [ User.viewLink User.Full userId user ]

        modsContent =
            if AssocList.isEmpty managers then
                [ Html.span [] [ Html.text "No bet managers." ]
                ]

            else
                [ Html.span [] [ Html.text "Bet managers:" ]
                , managers |> AssocList.toList |> List.map renderManager |> Html.ul []
                ]
    in
    Html.span [ HtmlA.class "bet-managers" ] modsContent


view : (Route -> msg) -> (Bets.Msg -> msg) -> Bets.Model -> Time.Context -> Maybe User.WithId -> Game.Id -> Game -> Html msg
view changeUrl wrap { favourites } time localUser id { name, cover, bets, progress, staked } =
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

        stakedDetails =
            [ Html.span [ HtmlA.class "total-staked" ] [ staked |> Coins.view Sentiment.Neutral, Html.text " bet in " ] ]

        normalContent =
            [ Html.img
                [ HtmlA.class "cover"
                , HtmlA.src cover
                , HtmlA.alt ""
                ]
                []
            , Html.h2 [ HtmlA.class "title" ]
                [ Html.text name
                , Html.span [ HtmlA.class "permalink" ] [ Icon.link |> Icon.view ]
                ]
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
                |> Html.span [ HtmlA.class "stats" ]
            , Html.span
                [ HtmlA.class "progress" ]
                progressView
            ]

        adminContent =
            if localUser |> Auth.canManageGames then
                [ Html.div [ HtmlA.class "admin-controls" ]
                    [ IconButton.icon (Icon.pen |> Icon.view) "Add Game"
                        |> Material.iconButtonLink changeUrl (id |> Just |> Edit.Game |> Route.Edit)
                        |> IconButton.view
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
                [ IconButton.icon (icon |> Icon.view)
                    "Favourite"
                    |> IconButton.button (action |> Bets.SetFavourite id |> wrap |> Just)
                    |> IconButton.view
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
