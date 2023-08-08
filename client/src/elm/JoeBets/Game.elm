module JoeBets.Game exposing
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
import JoeBets.Coins as Coins
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


view : (Bets.Msg -> msg) -> Bets.Model -> Time.Context -> Maybe User.WithId -> Game.Id -> Game -> Html msg
view wrap { favourites } time localUser id { name, cover, bets, progress, staked } =
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
            [ Html.span [ HtmlA.class "total-staked" ] [ staked |> Coins.view, Html.text " bet in " ] ]

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
