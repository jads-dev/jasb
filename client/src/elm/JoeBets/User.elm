module JoeBets.User exposing
    ( link
    , viewAvatar
    , viewBalance
    , viewBalanceOrTransaction
    , viewName
    , viewTransaction
    )

import Html exposing (Html)
import Html.Attributes as HtmlA
import JoeBets.Route as Route
import JoeBets.User.Model as User exposing (User)
import Url.Builder


viewName : { a | name : String, discriminator : String } -> Html msg
viewName { name, discriminator } =
    Html.span [ HtmlA.class "name" ]
        [ Html.text name
        , Html.span
            [ HtmlA.class "discriminator" ]
            [ Html.text "#", Html.text discriminator ]
        ]


viewAvatar : User.Id -> { a | discriminator : String, avatar : Maybe String } -> Html msg
viewAvatar id { discriminator, avatar } =
    let
        avatarPath =
            case avatar of
                Just hash ->
                    [ "avatars", User.idToString id, hash ++ ".png" ]

                Nothing ->
                    [ "embed", "avatars", discriminator ++ ".png" ]
    in
    Html.img
        [ HtmlA.class "avatar"
        , Url.Builder.crossOrigin "https://cdn.discordapp.com" avatarPath [] |> HtmlA.src
        ]
        []


viewBalance : Int -> Html msg
viewBalance score =
    viewBalanceOrTransaction score Nothing


viewTransaction : Int -> Int -> Html msg
viewTransaction before after =
    viewBalanceOrTransaction before (Just after)


viewBalanceOrTransaction : Int -> Maybe Int -> Html msg
viewBalanceOrTransaction before after =
    let
        goodBad score =
            Html.span
                [ HtmlA.classList [ ( "good", score > 0 ), ( "bad", score < 0 ) ] ]
                [ score |> String.fromInt |> Html.text ]

        rest afterAmount =
            [ Html.text " → ", goodBad afterAmount ]
    in
    Html.span [ HtmlA.class "score" ] (goodBad before :: (after |> Maybe.map rest |> Maybe.withDefault []))


link : User.WithId -> Html msg
link { id, user } =
    Route.a (id |> Just |> Route.User) [] [ viewAvatar id user, Html.text "You" ]
