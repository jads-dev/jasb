module JoeBets.Page.Leaderboard exposing
    ( init
    , load
    , update
    , view
    )

import AssocList
import FontAwesome as Icon
import FontAwesome.Solid as Icon
import Html
import Html.Attributes as HtmlA
import JoeBets.Api as Api
import JoeBets.Api.Data as Api
import JoeBets.Api.Path as Api
import JoeBets.Coins as Coins
import JoeBets.Messages as Global
import JoeBets.Page exposing (Page)
import JoeBets.Page.Leaderboard.Model exposing (..)
import JoeBets.Page.Leaderboard.Route as Route
import JoeBets.Route as Route
import JoeBets.User as User


wrap : Msg -> Global.Msg
wrap =
    Global.LeaderboardMsg


type alias Parent a =
    { a
        | leaderboard : Model
        , origin : String
    }


init : Model
init =
    { board = Route.NetWorth
    , netWorth = Api.initData
    , debt = Api.initData
    }


load : Route.Board -> Parent a -> ( Parent a, Cmd Global.Msg )
load board ({ leaderboard } as model) =
    let
        ( newLeaderboard, loadCmd ) =
            case board of
                Route.NetWorth ->
                    let
                        ( netWorth, cmd ) =
                            { path = Api.Leaderboard Route.NetWorth
                            , wrap = LoadNetWorth >> wrap
                            , decoder = netWorthEntriesDecoder
                            }
                                |> Api.get model.origin
                                |> Api.getData leaderboard.netWorth
                    in
                    ( { leaderboard | netWorth = netWorth, board = board }, cmd )

                Route.Debt ->
                    let
                        ( debt, cmd ) =
                            { path = Api.Leaderboard Route.Debt
                            , wrap = LoadDebt >> wrap
                            , decoder = debtEntriesDecoder
                            }
                                |> Api.get model.origin
                                |> Api.getData leaderboard.debt
                    in
                    ( { leaderboard | debt = debt, board = board }, cmd )
    in
    ( { model | leaderboard = newLeaderboard }, loadCmd )


update : Msg -> Parent a -> ( Parent a, Cmd Global.Msg )
update msg ({ leaderboard } as model) =
    case msg of
        LoadNetWorth result ->
            ( { model
                | leaderboard =
                    { leaderboard | netWorth = leaderboard.netWorth |> Api.updateData result }
              }
            , Cmd.none
            )

        LoadDebt result ->
            ( { model
                | leaderboard =
                    { leaderboard | debt = leaderboard.debt |> Api.updateData result }
              }
            , Cmd.none
            )


view : Parent a -> Page Global.Msg
view { leaderboard } =
    let
        viewNetWorth { netWorth } =
            Coins.view netWorth

        viewDebt { debt } =
            Coins.view debt

        body viewValue entries =
            let
                viewEntry ( id, { discriminator, name, value, rank } as entry ) =
                    Html.li []
                        [ Route.a (id |> Just |> Route.User)
                            []
                            [ Html.div [ HtmlA.class "rank" ] [ Html.span [] [ rank |> String.fromInt |> Html.text ] ]
                            , Html.div [ HtmlA.class "user-avatar" ] [ User.viewAvatar entry ]
                            , Html.div [ HtmlA.class "user-name" ] [ User.viewName entry ]
                            , Html.div [ HtmlA.class "value" ] [ viewValue value ]
                            ]
                        ]
            in
            if entries |> AssocList.isEmpty then
                [ Icon.ghost |> Icon.view ]

            else
                [ Html.ol [ HtmlA.class "leaderboard" ] (entries |> AssocList.toList |> List.map viewEntry) ]

        viewData =
            case leaderboard.board of
                Route.NetWorth ->
                    Api.viewData Api.viewOrError (body viewNetWorth) leaderboard.netWorth

                Route.Debt ->
                    Api.viewData Api.viewOrError (body viewDebt) leaderboard.debt

        tabButton icon name route =
            Html.li []
                [ Route.a (Route.Leaderboard route)
                    [ HtmlA.classList [ ( "active", leaderboard.board == route ) ] ]
                    [ icon |> Icon.view, Html.span [] [ Html.text name ] ]
                ]
    in
    { title = "Leaderboard"
    , id = "leaderboard"
    , body =
        Html.h2 [] [ Html.text "Leaderboard" ]
            :: Html.ul [ HtmlA.class "nav" ]
                [ tabButton Icon.crown "Highest Net Worth" Route.NetWorth
                , tabButton Icon.creditCard "Most Leveraged" Route.Debt
                ]
            :: viewData
    }
