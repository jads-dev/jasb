module Jasb.Page.Gacha.Route exposing
    ( EditTarget(..)
    , Route(..)
    , routeFromListOfStrings
    , routeParser
    , routeToListOfStrings
    )

import Jasb.Gacha.Banner as Banner
import Url.Parser as Url exposing ((</>))


type EditTarget
    = Banner
    | CardType Banner.Id


editTargetToListOfStrings : EditTarget -> List String
editTargetToListOfStrings editTarget =
    case editTarget of
        Banner ->
            [ "banners" ]

        CardType bannerId ->
            [ "banners", bannerId |> Banner.idToString, "card-types" ]


editTargetFromListOfStrings : List String -> Maybe EditTarget
editTargetFromListOfStrings route =
    case route of
        [ "banners" ] ->
            Just Banner

        "banners" :: bannerId :: [ "card-types" ] ->
            bannerId |> Banner.idFromString |> CardType |> Just

        _ ->
            Nothing


editTargetParser : Url.Parser (EditTarget -> a) a
editTargetParser =
    Url.oneOf
        [ Url.s "banners" |> Url.map Banner
        , Url.s "banners" </> Banner.idParser </> Url.s "card-types" |> Url.map CardType
        ]


type Route
    = Roll
    | PreviewBanner Banner.Id
    | Forge
    | Edit EditTarget


routeToListOfStrings : Route -> List String
routeToListOfStrings route =
    case route of
        Roll ->
            []

        PreviewBanner bannerId ->
            [ "banner", bannerId |> Banner.idToString ]

        Forge ->
            [ "forge" ]

        Edit editTarget ->
            "edit" :: editTargetToListOfStrings editTarget


routeFromListOfStrings : List String -> Maybe Route
routeFromListOfStrings route =
    case route of
        [] ->
            Just Roll

        "banner" :: bannerIdString :: [] ->
            bannerIdString |> Banner.idFromString |> PreviewBanner |> Just

        "edit" :: editTarget ->
            editTarget |> editTargetFromListOfStrings |> Maybe.map Edit

        _ ->
            Nothing


routeParser : Url.Parser (Route -> a) a
routeParser =
    Url.oneOf
        [ Url.top |> Url.map Roll
        , Url.s "banner" </> Banner.idParser |> Url.map PreviewBanner
        , Url.s "forge" |> Url.map Forge
        , Url.s "edit" </> editTargetParser |> Url.map Edit
        ]
