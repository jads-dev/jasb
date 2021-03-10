module JoeBets.Game exposing (view)

import FontAwesome.Icon as Icon
import FontAwesome.Solid as Icon
import Html exposing (Html)
import Html.Attributes as HtmlA
import Iso8601
import JoeBets.Game.Model as Game exposing (Game)
import JoeBets.Page.Edit.Model as Edit
import JoeBets.Route as Route
import JoeBets.User.Auth.Model as Auth
import JoeBets.User.Model as User exposing (User)
import Time
import Util.Time as Time


view : Time.Zone -> Time.Posix -> Maybe User.WithId -> Game.Id -> Game -> Html msg
view zone now localUser id { name, cover, bets, progress } =
    let
        usePastTense time =
            Time.posixToMillis time < Time.posixToMillis now

        viewDateTime future past posix =
            let
                describe =
                    if usePastTense posix then
                        past

                    else
                        future
            in
            [ describe |> Html.text
            , Html.text " "
            , Html.time
                [ posix |> Iso8601.fromTime |> HtmlA.datetime
                , posix |> Time.formatAsRelative now |> HtmlA.title
                ]
                [ posix |> Time.formatAsDate zone |> Html.text ]
            ]

        progressView =
            case progress of
                Game.Future _ ->
                    [ Html.text "Future Game" ]

                Game.Current { start } ->
                    viewDateTime "Starts" "Started" start

                Game.Finished { start, finish } ->
                    viewDateTime "Finished" "Finished" start

        normalContent =
            [ Html.img [ HtmlA.class "cover", HtmlA.src cover ] []
            , Html.div [ HtmlA.class "details" ]
                [ Route.a (Route.Bets id Nothing)
                    [ HtmlA.class "permalink" ]
                    [ Html.h2
                        [ HtmlA.class "title" ]
                        [ Html.text name, Icon.link |> Icon.present |> Icon.view ]
                    ]
                , Html.span [ HtmlA.class "bet-count" ] [ bets |> String.fromInt |> Html.text, Html.text " bet(s)." ]
                , Html.span [ HtmlA.class "progress" ] progressView
                ]
            ]

        adminContent =
            if localUser |> Auth.isMod id then
                [ Html.div [ HtmlA.class "admin-controls" ]
                    [ Route.a (id |> Just |> Edit.Game |> Route.Edit) [] [ Icon.pen |> Icon.present |> Icon.view ]
                    ]
                ]

            else
                []
    in
    [ normalContent, adminContent ] |> List.concat |> Html.div [ HtmlA.class "game" ]
