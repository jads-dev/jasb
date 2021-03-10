module JoeBets.Bet.Editor.OptionEditor exposing
    ( Model
    , Msg
    , fromOption
    , new
    , resolveId
    , toOption
    , update
    , validator
    , view
    )

import AssocList
import FontAwesome.Icon as Icon
import FontAwesome.Solid as Icon
import Html exposing (Html)
import Html.Attributes as HtmlA
import JoeBets.Bet.Editor.ProgressEditor as ProgressEditor
import JoeBets.Bet.Option as Option exposing (Option)
import JoeBets.Page.Edit.Validator as Validator exposing (Validator)
import Material.IconButton as IconButton
import Material.TextField as TextField
import Util.Url as Url


type Msg
    = ChangeId String
    | ChangeName String
    | ChangeImage String


type Id
    = Locked Option.Id
    | Manual Option.Id
    | Auto


type alias Model =
    { source : Maybe Option
    , id : Id
    , name : String
    , image : String
    }


new : Model
new =
    { source = Nothing
    , id = Auto
    , name = ""
    , image = ""
    }


fromOption : ( Option.Id, Option ) -> Model
fromOption ( id, option ) =
    { source = Just option
    , id = Locked id
    , name = option.name
    , image = option.image |> Maybe.withDefault ""
    }


resolveId : Model -> Option.Id
resolveId { id, name } =
    case id of
        Locked lockedId ->
            lockedId

        Manual manualId ->
            manualId

        Auto ->
            name |> Url.slugify |> Option.idFromString


toOption : Model -> ( Option.Id, Option )
toOption model =
    let
        image =
            if String.isEmpty model.image then
                Nothing

            else
                Just model.image

        stakes =
            model.source
                |> Maybe.map .stakes
                |> Maybe.withDefault AssocList.empty
    in
    ( resolveId model
    , Option model.name image stakes
    )


update : Msg -> Model -> Model
update msg model =
    case msg of
        ChangeId id ->
            { model | id = id |> Url.slugify |> Option.idFromString |> Manual }

        ChangeName name ->
            { model | name = name }

        ChangeImage image ->
            { model | image = image }


nameValidator : Validator Model
nameValidator =
    Validator.fromPredicate "Name must not be empty." (.name >> String.isEmpty)


validator : Validator Model
validator =
    Validator.all [ nameValidator ]


view : msg -> (Msg -> msg) -> (Int -> Maybe msg) -> (ProgressEditor.Msg -> msg) -> ProgressEditor.Model -> Int -> Model -> Html msg
view delete wrap reorderBy wrapProgressEditor progressEditor index model =
    let
        idAction =
            case model.id of
                Locked _ ->
                    Nothing

                _ ->
                    ChangeId >> wrap |> Just

        textField name type_ value action attrs =
            TextField.viewWithAttrs name type_ value action (HtmlA.attribute "outlined" "" :: attrs)

        content =
            Html.div [ HtmlA.class "option-editor" ]
                [ Html.span [ HtmlA.class "reorder" ]
                    [ IconButton.view (Icon.arrowUp |> Icon.present |> Icon.view) "Move Up" (reorderBy -1)
                    , IconButton.view (Icon.arrowDown |> Icon.present |> Icon.view) "Move Down" (reorderBy 1)
                    ]
                , Html.div [ HtmlA.class "details" ]
                    [ Html.div [ HtmlA.class "inline" ]
                        [ Html.span [ HtmlA.class "fullwidth" ]
                            [ textField "Id" TextField.Text (resolveId model |> Option.idToString) idAction [] ]
                        , ProgressEditor.viewMakeWinnerButton wrapProgressEditor index progressEditor |> Maybe.withDefault (Html.text "")
                        , IconButton.view (Icon.trash |> Icon.present |> Icon.view) "Delete" (Just delete)
                        ]
                    , textField "Name" TextField.Text model.name (ChangeName >> wrap |> Just) [ HtmlA.required True ]
                    , Validator.view nameValidator model
                    , textField "Image" TextField.Url model.image (ChangeImage >> wrap |> Just) []
                    ]
                ]
    in
    content
