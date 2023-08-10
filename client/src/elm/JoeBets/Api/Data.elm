module JoeBets.Api.Data exposing
    ( Data
    , ViewModel
    , dataToMaybe
    , getData
    , ifNotDataLoading
    , initData
    , initDataFromError
    , initDataFromValue
    , initFromAll
    , initGetData
    , isLoaded
    , isLoading
    , mapData
    , spinnerIfLoading
    , updateData
    , viewData
    , viewErrorIfFailed
    , viewOrError
    , viewOrNothing
    )

import FontAwesome as Icon
import FontAwesome.Attributes as Icon
import FontAwesome.Solid as Icon
import Html exposing (Html)
import Html.Attributes as HtmlA
import JoeBets.Api.Error exposing (..)
import JoeBets.Api.Model exposing (..)
import JoeBets.Error as Error
import Svg.Attributes as SvgA


type Data value
    = Data
        { value : Maybe value
        , loading : Bool
        , problem : Maybe Error
        }


initData : Data value
initData =
    Data
        { value = Nothing
        , loading = False
        , problem = Nothing
        }


{-| For internal use.
-}
initFromAll : Maybe value -> Bool -> Maybe Error -> Data value
initFromAll value loading problem =
    Data { value = value, loading = loading, problem = problem }


getData : Data value -> Cmd msg -> ( Data value, Cmd msg )
getData (Data data) getRequest =
    ( Data { data | loading = True }, getRequest )


initGetData : Cmd msg -> ( Data value, Cmd msg )
initGetData =
    getData initData


initDataFromValue : value -> Data value
initDataFromValue value =
    Data { value = Just value, loading = False, problem = Nothing }


initDataFromError : Error -> Data value
initDataFromError error =
    Data { value = Nothing, loading = False, problem = Just error }


mapData : (a -> b) -> Data a -> Data b
mapData f (Data data) =
    Data
        { loading = data.loading
        , value = data.value |> Maybe.map f
        , problem = data.problem
        }


dataToMaybe : Data value -> Maybe value
dataToMaybe (Data data) =
    data.value


isLoading : Data value -> Bool
isLoading (Data data) =
    data.loading


isLoaded : Data value -> Bool
isLoaded (Data data) =
    data.value /= Nothing


ifNotDataLoading : Data value -> Maybe msg -> Maybe msg
ifNotDataLoading data action =
    if isLoading data then
        Nothing

    else
        action


updateData : Response value -> Data value -> Data value
updateData response (Data data) =
    let
        updateValueOrError d =
            case response of
                Ok value ->
                    { d | value = Just value, problem = Nothing }

                Err error ->
                    { d | problem = Just error }

        noLongerLoading d =
            { d | loading = False }
    in
    data |> updateValueOrError |> noLongerLoading |> Data


viewErrorIfFailed : Data value -> List (Html msg)
viewErrorIfFailed (Data data) =
    case data.problem of
        Just error ->
            [ viewError error ]

        Nothing ->
            []


type alias ViewModel msg =
    { container : List (Html msg) -> List (Html msg)
    , default : List (Html msg)
    , loadingDescription : List (Html msg)
    }


viewOrError : ViewModel msg
viewOrError =
    { container = identity
    , default =
        [ Error.view
            { reason =
                Error.ApplicationBug
                    { developerDetail = "API data never started loading." }
            , message = "Loading failed, please try refreshing."
            }
        ]
    , loadingDescription =
        [ Html.div [ HtmlA.class "description" ]
            [ Html.text "Loading..." ]
        ]
    }


spinnerIfLoading : Data value -> Html msg -> Html msg
spinnerIfLoading (Data data) icon =
    if data.loading then
        Icon.spinner |> Icon.styled [ Icon.spinPulse ] |> Icon.view

    else
        icon


viewOrNothing : ViewModel msg
viewOrNothing =
    { container = identity
    , default = []
    , loadingDescription =
        [ Html.div [ HtmlA.class "description" ]
            [ Html.text "Loading..." ]
        ]
    }


viewData : ViewModel msg -> (value -> List (Html msg)) -> Data value -> List (Html msg)
viewData { default, container, loadingDescription } viewValue ((Data { loading, problem, value }) as data) =
    if not loading && problem == Nothing && value == Nothing then
        default

    else
        let
            loadingIfNeeded =
                if loading then
                    let
                        spinner =
                            Icon.spinner
                                |> Icon.styled
                                    [ SvgA.class "spinner"
                                    , Icon.spinPulse
                                    ]
                                |> Icon.view
                    in
                    if value == Nothing then
                        Just (spinner :: loadingDescription)

                    else
                        Just [ spinner ]

                else
                    Nothing

            wrapLoading loadingContent =
                [ Html.div [ HtmlA.class "loading" ] loadingContent ]

            loadingWrapped =
                loadingIfNeeded
                    |> Maybe.map wrapLoading
                    |> Maybe.withDefault []

            problemIfExists =
                viewErrorIfFailed data

            valueIfExists =
                value |> Maybe.map viewValue |> Maybe.withDefault []
        in
        [ loadingWrapped
        , problemIfExists
        , valueIfExists
        ]
            |> List.concat
            |> container
