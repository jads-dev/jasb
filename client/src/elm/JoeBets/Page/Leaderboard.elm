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
import Http
import JoeBets.Api as Api
import JoeBets.Coins as Coins
import JoeBets.Page exposing (Page)
import JoeBets.Page.Leaderboard.Model exposing (..)
import JoeBets.Page.Leaderboard.Route as Route
import JoeBets.Route as Route
import JoeBets.User as User
import Util.RemoteData as RemoteData


type alias Parent a =
    { a
        | leaderboard : Model
        , origin : String
    }


init : Model
init =
    Model Route.NetWorth RemoteData.Missing RemoteData.Missing


load : (Msg -> msg) -> Route.Board -> Parent a -> ( Parent a, Cmd msg )
load wrap board model =
    let
        leaderboard =
            model.leaderboard

        loadBoard =
            case board of
                Route.NetWorth ->
                    Http.expectJson (LoadNetWorth >> wrap) netWorthEntriesDecoder

                Route.Debt ->
                    Http.expectJson (LoadDebt >> wrap) debtEntriesDecoder
    in
    ( { model | leaderboard = { leaderboard | board = board } }
    , Api.get model.origin
        { path = Api.Leaderboard board
        , expect = loadBoard
        }
    )


update : Msg -> Parent a -> ( Parent a, Cmd msg )
update msg model =
    case msg of
        LoadNetWorth result ->
            let
                leaderboard =
                    model.leaderboard
            in
            ( { model
                | leaderboard =
                    { leaderboard | netWorth = RemoteData.load result }
              }
            , Cmd.none
            )

        LoadDebt result ->
            let
                leaderboard =
                    model.leaderboard
            in
            ( { model
                | leaderboard =
                    { leaderboard | debt = RemoteData.load result }
              }
            , Cmd.none
            )


view : (Msg -> msg) -> Parent a -> Page msg
view _ { leaderboard } =
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
                            , Html.div [ HtmlA.class "user-avatar" ] [ User.viewAvatar id entry ]
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
                    RemoteData.view (body viewNetWorth) leaderboard.netWorth

                Route.Debt ->
                    RemoteData.view (body viewDebt) leaderboard.debt

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
