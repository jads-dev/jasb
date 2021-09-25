module JoeBets.Game exposing (view)

import AssocList
import EverySet
import FontAwesome.Icon as Icon
import FontAwesome.Regular as OutlineIcon
import FontAwesome.Solid as Icon
import Html exposing (Html)
import Html.Attributes as HtmlA
import JoeBets.Coins as Coins
import JoeBets.Game.Details as Game
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

        renderMod ( userId, user ) =
            Html.li []
                [ Route.a (userId |> Just |> Route.User)
                    [ HtmlA.class "user permalink" ]
                    [ User.viewAvatar userId user
                    , Html.text user.name
                    , Icon.link |> Icon.present |> Icon.view
                    ]
                ]

        renderDetails { mods, staked } =
            let
                modsContent =
                    if AssocList.isEmpty mods then
                        [ Html.span [] [ Html.text "No bet managers." ]
                        ]

                    else
                        [ Html.span [] [ Html.text "Bet managers:" ]
                        , mods |> AssocList.toList |> List.map renderMod |> Html.ul []
                        ]
            in
            ( [ Html.span [ HtmlA.class "mods" ] modsContent ]
            , [ Html.span [ HtmlA.class "total-staked" ] [ staked |> Coins.view, Html.text " bet in " ] ]
            )

        ( modDetails, stakedDetails ) =
            details |> Maybe.map renderDetails |> Maybe.withDefault ( [], [] )

        normalContent =
            [ [ Route.a (Route.Bets Bets.Active id) [] [ Html.img [ HtmlA.class "cover", HtmlA.src cover ] [] ]
              , Html.div [ HtmlA.class "details" ]
                    [ Route.a (Route.Bets Bets.Active id)
                        [ HtmlA.class "permalink" ]
                        [ Html.h2
                            [ HtmlA.class "title" ]
                            [ Html.text name, Icon.link |> Icon.present |> Icon.view ]
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
                        |> Html.span []
                    , Html.span
                        [ HtmlA.class "progress" ]
                        progressView
                    ]
              ]
            , modDetails
            ]

        adminContent =
            if localUser |> Auth.isMod id then
                [ Html.div [ HtmlA.class "admin-controls" ]
                    [ Route.a (id |> Just |> Edit.Game |> Route.Edit) [] [ Icon.pen |> Icon.present |> Icon.view ]
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
                [ IconButton.view (icon |> Icon.present |> Icon.view)
                    "Favourite"
                    (action |> Bets.SetFavourite id |> wrap |> Just)
                ]

        interactions =
            [ Html.div [ HtmlA.class "interactions" ] (favouriteControl :: adminContent) ]
    in
    [ List.concat normalContent, interactions ]
        |> List.concat
        |> Html.div [ HtmlA.classList [ ( "game", True ), ( "favourite", isFavourite ) ] ]
