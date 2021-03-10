module Util.RemoteData exposing
    ( RemoteData(..)
    , Response
    , errorToString
    , load
    , map
    , toMaybe
    , view
    )

import FontAwesome.Attributes as Icon
import FontAwesome.Icon as Icon
import FontAwesome.Solid as Icon
import Html exposing (Html)
import Html.Attributes as HtmlA
import Http


type RemoteData value
    = Missing
    | Loaded value
    | Failed Http.Error


type alias Response value =
    Result Http.Error value


map : (a -> b) -> RemoteData a -> RemoteData b
map f a =
    case a of
        Loaded value ->
            value |> f |> Loaded

        Missing ->
            Missing

        Failed error ->
            Failed error


toMaybe : RemoteData value -> Maybe value
toMaybe remoteData =
    case remoteData of
        Missing ->
            Nothing

        Loaded value ->
            Just value

        Failed _ ->
            Nothing


load : Response value -> RemoteData value
load response =
    case response of
        Ok value ->
            Loaded value

        Err error ->
            Failed error


view : (value -> List (Html msg)) -> RemoteData value -> List (Html msg)
view viewValue remoteData =
    case remoteData of
        Missing ->
            [ Html.div [ HtmlA.class "loading" ]
                [ Icon.spinner |> Icon.present |> Icon.styled [ Icon.pulse ] |> Icon.view ]
            ]

        Loaded value ->
            viewValue value

        Failed error ->
            [ Html.div [ HtmlA.class "error" ] [ error |> errorToString |> Html.text ] ]


errorToString : Http.Error -> String
errorToString error =
    case error of
        Http.BadUrl url ->
            "Invalid URL: " ++ url

        Http.Timeout ->
            "Timeout"

        Http.NetworkError ->
            "Network error."

        Http.BadStatus code ->
            "Bad status from server: " ++ (code |> String.fromInt)

        Http.BadBody bodyIssue ->
            "Bad response from server: " ++ bodyIssue
