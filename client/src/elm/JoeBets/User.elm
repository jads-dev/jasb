module JoeBets.User exposing
    ( ViewMode(..)
    , link
    , viewAvatar
    , viewLink
    , viewName
    )

import Bitwise exposing (shiftRightBy)
import Html exposing (Html)
import Html.Attributes as HtmlA
import JoeBets.Route as Route
import JoeBets.User.Auth.Model exposing (RedirectOrLoggedIn(..))
import JoeBets.User.Model exposing (..)
import Url.Builder
import Util.Html as Html


type ViewMode
    = Compact
    | Full


type alias UserLikeWithAvatar a =
    { a
        | name : String
        , discriminator : Maybe String
        , avatar : Maybe String
        , avatarCache : Maybe String
    }


viewLink : ViewMode -> Id -> UserLikeWithAvatar a -> Html msg
viewLink viewMode id user =
    Route.a (id |> Just |> Route.User)
        [ HtmlA.classList [ ( "user", True ), ( "permalink", True ), ( "compact", viewMode == Compact ) ] ]
        [ viewAvatar id user
        , viewName user
        ]


viewName : { a | name : String, discriminator : Maybe String } -> Html msg
viewName { name, discriminator } =
    let
        suffix =
            case discriminator of
                Nothing ->
                    []

                Just value ->
                    [ Html.span
                        [ HtmlA.class "discriminator" ]
                        [ Html.text "#", Html.text value ]
                    ]
    in
    Html.span [ HtmlA.class "name" ]
        (Html.text name :: suffix)


viewAvatar : Id -> UserLikeWithAvatar a -> Html msg
viewAvatar id { discriminator, avatar, avatarCache } =
    let
        sharedAttrs =
            [ HtmlA.attribute "loading" "lazy"
            , HtmlA.class "avatar"
            ]
    in
    case avatarCache of
        Just cacheSrc ->
            Html.img
                (HtmlA.src cacheSrc
                    :: HtmlA.alt ""
                    :: sharedAttrs
                )
                []

        Nothing ->
            let
                discordUrl path =
                    Url.Builder.crossOrigin "https://cdn.discordapp.com" path []

                fallbackSrc =
                    let
                        default =
                            case discriminator of
                                Just value ->
                                    value |> String.toInt |> Maybe.map (modBy 5)

                                Nothing ->
                                    id |> idToString |> String.toInt |> Maybe.map (shiftRightBy 22 >> modBy 6)

                        defaultString =
                            default |> Maybe.withDefault 0 |> String.fromInt
                    in
                    [ "embed", "avatars", defaultString ++ ".png" ] |> discordUrl

                src =
                    avatar |> Maybe.map (\hash -> [ "avatars", idToString id, hash ++ ".png" ] |> discordUrl)

                imgOrFallback alt image fallback attrs =
                    case image of
                        Just imageSrc ->
                            Html.imgFallback { src = imageSrc, alt = alt } { src = fallback, alt = Nothing } attrs

                        Nothing ->
                            Html.img (HtmlA.src fallback :: HtmlA.alt alt :: attrs) []
            in
            imgOrFallback "" src fallbackSrc sharedAttrs


link : WithId -> Html msg
link { id, user } =
    Route.a (id |> Just |> Route.User) [] [ viewAvatar id user, Html.text "You" ]
