module JoeBets.User exposing
    ( ViewMode(..)
    , link
    , viewAvatar
    , viewLink
    , viewName
    )

import Html exposing (Html)
import Html.Attributes as HtmlA
import JoeBets.Route as Route
import JoeBets.User.Model exposing (..)
import Url.Builder
import Util.Html as Html


type ViewMode
    = Compact
    | Full


viewLink : ViewMode -> Id -> { a | name : String, discriminator : String, avatar : Maybe String } -> Html msg
viewLink viewMode id user =
    Route.a (id |> Just |> Route.User)
        [ HtmlA.classList [ ( "user", True ), ( "permalink", True ), ( "compact", viewMode == Compact ) ] ]
        [ viewAvatar id user
        , viewName user
        ]


viewName : { a | name : String, discriminator : String } -> Html msg
viewName { name, discriminator } =
    Html.span [ HtmlA.class "name" ]
        [ Html.text name
        , Html.span
            [ HtmlA.class "discriminator" ]
            [ Html.text "#", Html.text discriminator ]
        ]


viewAvatar : Id -> { a | name : String, discriminator : String, avatar : Maybe String } -> Html msg
viewAvatar id { name, discriminator, avatar } =
    let
        discordUrl path =
            Url.Builder.crossOrigin "https://cdn.discordapp.com" path []

        fallbackSrc =
            let
                default =
                    discriminator |> String.toInt |> Maybe.map (modBy 5) |> Maybe.withDefault 0 |> String.fromInt
            in
            [ "embed", "avatars", default ++ ".png" ] |> discordUrl

        src =
            avatar |> Maybe.map (\hash -> [ "avatars", idToString id, hash ++ ".png" ] |> discordUrl)

        imgOrFallback alt image fallback attrs =
            case image of
                Just imageSrc ->
                    Html.imgFallback { src = imageSrc, alt = name } { src = fallback, alt = Nothing } attrs

                Nothing ->
                    Html.img ([ HtmlA.src fallback, HtmlA.alt alt ] ++ attrs) []
    in
    imgOrFallback name src fallbackSrc [ HtmlA.class "avatar" ]


link : WithId -> Html msg
link { id, user } =
    Route.a (id |> Just |> Route.User) [] [ viewAvatar id user, Html.text "You" ]
