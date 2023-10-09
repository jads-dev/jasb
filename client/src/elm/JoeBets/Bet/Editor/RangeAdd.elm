module JoeBets.Bet.Editor.RangeAdd exposing
    ( Model
    , Msg(..)
    , init
    , update
    , view
    )

import FontAwesome as Icon
import FontAwesome.Solid as Icon
import Html exposing (Html)
import Html.Attributes as HtmlA
import Material.Button as Button
import Material.Dialog as Dialog
import Material.Switch as Switch
import Material.TextField as TextField
import Util.List as List


type Style
    = Discrete
    | Continuous


type alias Model =
    { open : Bool
    , start : Int
    , step : Int
    , stop : Int
    , style : Style
    }


type Msg
    = Show
    | ChangeStart String
    | ChangeStep String
    | ChangeStop String
    | ChangeStyle Bool
    | Cancel
    | Add


init : Model
init =
    { open = False, start = 0, stop = 10, step = 1, style = Discrete }


toOptionNames : Model -> List String
toOptionNames { start, step, stop, style } =
    let
        rangeName =
            case style of
                Discrete ->
                    \rangeStart ->
                        if step < 2 then
                            String.fromInt rangeStart

                        else
                            String.fromInt rangeStart ++ "–" ++ (rangeStart + (step - 1) |> String.fromInt)

                Continuous ->
                    \rangeStart ->
                        "≥ " ++ String.fromInt rangeStart ++ ", <" ++ (rangeStart + step |> String.fromInt)
    in
    List.stepRange start step stop |> List.map rangeName


update : Msg -> Model -> ( Model, Maybe (List String) )
update msg model =
    case msg of
        Show ->
            ( { model | open = True }, Nothing )

        ChangeStart start ->
            ( { model
                | start =
                    start
                        |> String.toInt
                        |> Maybe.withDefault model.start
                        |> min model.stop
              }
            , Nothing
            )

        ChangeStep step ->
            ( { model
                | step =
                    step
                        |> String.toInt
                        |> Maybe.withDefault model.step
                        |> max 1
              }
            , Nothing
            )

        ChangeStop stop ->
            ( { model
                | stop =
                    stop
                        |> String.toInt
                        |> Maybe.withDefault model.stop
                        |> max model.start
              }
            , Nothing
            )

        ChangeStyle continuous ->
            ( { model
                | style =
                    if continuous then
                        Continuous

                    else
                        Discrete
              }
            , Nothing
            )

        Cancel ->
            ( { model | open = False }, Nothing )

        Add ->
            ( { model | open = False }
            , model |> toOptionNames |> Just
            )


preview : Model -> Html msg
preview model =
    let
        viewItem name =
            Html.li [] [ Html.text name ]
    in
    [ Html.h3 [] [ Html.text "Preview" ]
    , model |> toOptionNames |> List.map viewItem |> Html.ol []
    ]
        |> Html.div [ HtmlA.class "preview-ranges" ]


view : (Msg -> msg) -> Model -> Html msg
view wrap ({ open, start, step, stop, style } as model) =
    Dialog.dialog (Cancel |> wrap)
        [ Html.div [ HtmlA.class "controls" ]
            [ start
                |> String.fromInt
                |> TextField.outlined "Start" (ChangeStart >> wrap |> Just)
                |> TextField.number
                |> TextField.supportingText "The number to start from (inclusive)."
                |> TextField.view
            , step
                |> String.fromInt
                |> TextField.outlined "Step" (ChangeStep >> wrap |> Just)
                |> TextField.number
                |> TextField.supportingText "The size of each range."
                |> TextField.view
            , stop
                |> String.fromInt
                |> TextField.outlined "Stop" (ChangeStop >> wrap |> Just)
                |> TextField.number
                |> TextField.supportingText "The number to end at (inclusive, will overshoot if step doesn't go evenly)."
                |> TextField.view
            , Html.div [ HtmlA.class "style" ]
                [ Html.label []
                    [ Html.text "Continous"
                    , Switch.switch
                        (ChangeStyle >> wrap |> Just)
                        (style == Continuous)
                        |> Switch.view
                    ]
                , Html.p [] [ Html.text "If a bet could technically land at a fractional point between a range, disambiguates." ]
                ]
            ]
        , preview model
        ]
        [ Button.text "Cancel"
            |> Button.button (Cancel |> wrap |> Just)
            |> Button.icon [ Icon.times |> Icon.view ]
            |> Button.view
        , Button.filled "Add Ranges"
            |> Button.button (Add |> wrap |> Just)
            |> Button.icon [ Icon.plus |> Icon.view ]
            |> Button.view
        ]
        open
        |> Dialog.headline [ Html.text "Add numeric ranges." ]
        |> Dialog.attrs [ HtmlA.class "add-ranges-dialog" ]
        |> Dialog.view
