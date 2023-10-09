module JoeBets.Bet.Editor.QuickAdd exposing
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
import Material.TextField as TextField


type alias Model =
    { open : Bool, value : String }


type Msg
    = Show
    | Change String
    | Cancel
    | Add


init : Model
init =
    { open = False, value = "" }


update : Msg -> Model -> ( Model, Maybe (List String) )
update msg model =
    case msg of
        Show ->
            ( { model | open = True, value = "" }, Nothing )

        Change value ->
            ( { model | value = value }, Nothing )

        Cancel ->
            ( { model | open = False }, Nothing )

        Add ->
            ( { model | open = False }
            , model.value |> String.split "\n" |> List.map String.trim |> Just
            )


view : (Msg -> msg) -> Model -> Html msg
view wrap { value, open } =
    Dialog.dialog (Cancel |> wrap)
        [ TextField.outlined "Options" (Change >> wrap |> Just) value
            |> TextField.textArea
            |> TextField.supportingText "The names of options you wish to add, one per line."
            |> TextField.view
        ]
        [ Button.text "Cancel"
            |> Button.button (Cancel |> wrap |> Just)
            |> Button.icon [ Icon.times |> Icon.view ]
            |> Button.view
        , Button.filled "Add All"
            |> Button.button (Add |> wrap |> Just)
            |> Button.icon [ Icon.plus |> Icon.view ]
            |> Button.view
        ]
        open
        |> Dialog.headline
            [ Html.text "Add many options." ]
        |> Dialog.attrs [ HtmlA.class "quick-add-dialog" ]
        |> Dialog.view
