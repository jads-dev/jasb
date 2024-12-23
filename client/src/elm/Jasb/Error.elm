module Jasb.Error exposing
    ( Details
    , Reason(..)
    , toString
    , view
    )

import FontAwesome as Icon exposing (Icon)
import FontAwesome.Solid as Icon
import Html exposing (Html)
import Html.Attributes as HtmlA


type Reason
    = ApplicationBug { developerDetail : String }
    | TransientProblem
    | UserMistake


type alias Details =
    { reason : Reason
    , message : String
    }


reasonToIcon : Reason -> Icon Icon.WithoutId
reasonToIcon reason =
    case reason of
        ApplicationBug _ ->
            Icon.bug

        TransientProblem ->
            Icon.exclamationCircle

        UserMistake ->
            Icon.triangleExclamation


reasonToMessageAndDetails : Reason -> ( String, Maybe String )
reasonToMessageAndDetails reason =
    case reason of
        ApplicationBug { developerDetail } ->
            ( "An error occurred within JASB, please report this bug"
            , Just developerDetail
            )

        TransientProblem ->
            ( "There appears to be a temporary problem", Nothing )

        UserMistake ->
            ( "There was a problem", Nothing )


view : Details -> Html msg
view { reason, message } =
    let
        detailsIfPresent givenDetails =
            [ Html.div [ HtmlA.class "details" ]
                [ Html.span [] [ Html.text "Details to report:" ]
                , Html.text " "
                , Html.span [] [ Html.text givenDetails ]
                ]
            ]

        ( reasonMessage, details ) =
            reasonToMessageAndDetails reason

        contents =
            Html.span [ HtmlA.class "icon" ] [ reason |> reasonToIcon |> Icon.view ]
                :: Html.span [ HtmlA.class "reason" ] [ reasonMessage |> Html.text, Html.text ":" ]
                :: Html.text " "
                :: Html.span [ HtmlA.class "message" ] [ message |> Html.text ]
                :: Html.text " "
                :: (details |> Maybe.map detailsIfPresent |> Maybe.withDefault [])
    in
    Html.div [ HtmlA.class "error" ] contents


toString : Details -> String
toString { reason, message } =
    let
        ( reasonMessage, details ) =
            reasonToMessageAndDetails reason
    in
    [ reasonMessage
    , ": "
    , message
    , details |> Maybe.map (\d -> " " ++ d) |> Maybe.withDefault ""
    ]
        |> String.concat
