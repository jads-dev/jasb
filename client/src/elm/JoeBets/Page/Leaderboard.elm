module JoeBets.Page.Leaderboard exposing
    ( init
    , load
    , update
    , view
    )

import AssocList
import FontAwesome.Icon as Icon
import FontAwesome.Solid as Icon
import Html
import Html.Attributes as HtmlA
import Http
import JoeBets.Api as Api
import JoeBets.Coins as Coins
import JoeBets.Page exposing (Page)
import JoeBets.Page.Leaderboard.Model as Loaderboard exposing (Model, Msg(..))
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
    RemoteData.Missing


load : (Msg -> msg) -> Parent a -> ( Parent a, Cmd msg )
load wrap model =
    ( model
    , Api.get model.origin
        { path = Api.Leaderboard
        , expect = Http.expectJson (Load >> wrap) Loaderboard.decoder
        }
    )


update : Msg -> Parent a -> ( Parent a, Cmd msg )
update msg model =
    case msg of
        Load result ->
            case result of
                Ok leaderboard ->
                    ( { model | leaderboard = RemoteData.Loaded leaderboard }, Cmd.none )

                Err error ->
                    ( { model | leaderboard = RemoteData.Failed error }, Cmd.none )


view : (Msg -> msg) -> Parent a -> Page msg
view _ { leaderboard } =
    let
        body entries =
            let
                viewEntry ( id, { discriminator, name, netWorth, rank } as entry ) =
                    Html.li []
                        [ Html.span [ HtmlA.class "rank" ] [ rank |> String.fromInt |> Html.text ]
                        , Route.a (id |> Just |> Route.User)
                            []
                            [ User.viewAvatar id entry
                            , User.viewName entry
                            , Coins.view netWorth
                            ]
                        ]
            in
            if entries |> AssocList.isEmpty then
                [ Icon.ghost |> Icon.present |> Icon.view ]

            else
                [ Html.ol [ HtmlA.class "leaderboard" ] (entries |> AssocList.toList |> List.map viewEntry) ]
    in
    { title = "Leaderboard"
    , id = "leaderboard"
    , body = leaderboard |> RemoteData.view body
    }
