module JoeBets.User exposing
    ( ViewMode(..)
    , link
    , nameString
    , viewAvatar
    , viewLink
    , viewName
    )

import Html exposing (Html)
import Html.Attributes as HtmlA
import JoeBets.Route as Route
import JoeBets.User.Model exposing (..)


type ViewMode
    = Compact
    | Full


type alias UserLikeWithAvatar a =
    { a
        | name : String
        , discriminator : Maybe String
        , avatar : String
    }


viewLink : ViewMode -> Id -> UserLikeWithAvatar a -> Html msg
viewLink viewMode id user =
    Route.a (id |> Just |> Route.User)
        [ HtmlA.classList [ ( "user", True ), ( "permalink", True ), ( "compact", viewMode == Compact ) ] ]
        [ viewAvatar user
        , viewName user
        ]


nameString : { a | name : String, discriminator : Maybe String } -> String
nameString { name, discriminator } =
    let
        suffix =
            case discriminator of
                Nothing ->
                    ""

                Just value ->
                    "#" ++ value
    in
    name ++ suffix


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


viewAvatar : UserLikeWithAvatar a -> Html msg
viewAvatar user =
    let
        sharedAttrs =
            [ HtmlA.attribute "loading" "lazy"
            , HtmlA.class "avatar"
            ]
    in
    Html.img
        (HtmlA.src user.avatar
            :: HtmlA.alt (nameString user ++ "'s Avatar")
            :: sharedAttrs
        )
        []


link : WithId -> Html msg
link { id, user } =
    Route.a (id |> Just |> Route.User)
        [ HtmlA.class "user" ]
        [ viewAvatar user
        , viewName user
        ]
