module Jasb.Page.Gacha.Edit.CardType exposing
    ( loadCardTypesEditor
    , updateCardTypesEditor
    , viewCardTypesEditor
    )

import AssocList
import FontAwesome as Icon
import FontAwesome.Solid as Icon
import Html exposing (Html)
import Html.Attributes as HtmlA
import Html.Keyed as HtmlK
import Http
import Jasb.Api as Api
import Jasb.Api.Action as Api
import Jasb.Api.Data as Api
import Jasb.Api.IdData as Api
import Jasb.Api.Model as Api
import Jasb.Api.Path as Api
import Jasb.Editing.Uploader as Uploader
import Jasb.Editing.Validator as Validator exposing (Validator)
import Jasb.Gacha.Banner as Banner
import Jasb.Gacha.Card.Layout as Card
import Jasb.Gacha.CardType as CardType exposing (EditableCardType, EditableCardTypes)
import Jasb.Gacha.Context.Model as Gacha
import Jasb.Gacha.Rarity as Rarity
import Jasb.Messages as Global
import Jasb.Page exposing (Page)
import Jasb.Page.Gacha.Card as Card
import Jasb.Page.Gacha.Edit.CardType.CreditEditor as CreditEditor
import Jasb.Page.Gacha.Edit.CardType.Model exposing (..)
import Jasb.Page.Gacha.Edit.CardType.RaritySelector as Rarity
import Jasb.Page.Gacha.Model as Gacha
import Json.Encode as JsonE
import Material.Button as Button
import Material.Dialog as Dialog
import Material.IconButton as IconButton
import Material.Switch as Switch
import Material.TextField as TextField
import Task
import Time.DateTime as DateTime
import Time.Model as Time
import Util.AssocList as AssocList


wrapGacha : Gacha.Msg -> Global.Msg
wrapGacha =
    Global.GachaMsg


wrap : Msg -> Global.Msg
wrap =
    Gacha.EditCardTypes >> Gacha.EditMsg >> wrapGacha


type alias Parent a =
    { a
        | origin : String
        , time : Time.Context
        , gacha : Gacha.Model
    }


imageUploaderModel : Card.Layout -> Uploader.Model
imageUploaderModel layout =
    { label = "Image"
    , types = [ "image/*" ]
    , path = Api.CardImageUpload |> Api.Gacha
    , extraParts = [ layout |> Card.encodeLayout |> JsonE.encode 0 |> Http.stringPart "layout" ]
    }


loadCardTypesEditor : Banner.Id -> Parent a -> ( Parent a, Cmd Global.Msg )
loadCardTypesEditor bannerId ({ gacha } as model) =
    let
        ( state, cmd ) =
            { path = Api.EditableCardTypes |> Api.SpecificBanner bannerId |> Api.Banners |> Api.Gacha
            , wrap = Load bannerId >> wrap
            , decoder = CardType.editableCardTypesDecoder
            }
                |> Api.get model.origin
                |> Api.getIdData bannerId model.gacha.editableCardTypes
    in
    ( { model | gacha = { gacha | editableCardTypes = state } }, cmd )


updateEditor : (Parent a -> Gacha.Model -> Maybe Editor -> Maybe Editor) -> Parent a -> Parent a
updateEditor doUpdate ({ gacha } as model) =
    { model
        | gacha =
            { gacha | cardTypeEditor = gacha.cardTypeEditor |> doUpdate model gacha }
    }


updateEditorEdit : (Parent a -> Gacha.Model -> Editor -> Editor) -> Parent a -> Parent a
updateEditorEdit doUpdate =
    let
        edit model gacha editor =
            editor |> Maybe.map (doUpdate model gacha)
    in
    updateEditor edit


updateCardTypesEditor : Msg -> Parent a -> ( Parent a, Cmd Global.Msg )
updateCardTypesEditor msg ({ gacha } as model) =
    case msg of
        Load bannerId response ->
            ( { model
                | gacha =
                    { gacha
                        | editableCardTypes =
                            gacha.editableCardTypes |> Api.updateIdData bannerId response
                    }
              }
            , Cmd.none
            )

        Add bannerId maybeTime ->
            case maybeTime of
                Just time ->
                    let
                        newCardType =
                            EditableCardType "" "" "" False (Rarity.idFromString "m") Card.Normal AssocList.empty 0 time time

                        startAdd _ _ _ =
                            Editor
                                True
                                bannerId
                                newCardType
                                Uploader.init
                                CreditEditor.init
                                Api.initAction
                                Nothing
                                |> Just
                    in
                    ( updateEditor startAdd model, Cmd.none )

                Nothing ->
                    ( model
                    , DateTime.getNow |> Task.perform (Just >> Add bannerId >> wrap)
                    )

        Edit bannerId id ->
            let
                fromCardType cardType =
                    Editor
                        True
                        bannerId
                        cardType
                        (Uploader.fromUrl cardType.image)
                        (CreditEditor.initFromExisting cardType.credits)
                        Api.initAction
                        (Just id)

                startEdit : Parent a -> Gacha.Model -> Maybe Editor -> Maybe Editor
                startEdit _ g _ =
                    g.editableCardTypes
                        |> Api.idDataToMaybe
                        |> Maybe.andThen (Tuple.second >> AssocList.get id)
                        |> Maybe.map fromCardType
            in
            ( updateEditor startEdit model, Cmd.none )

        Cancel ->
            let
                cancel editor =
                    { editor | open = False }
            in
            ( updateEditor (\_ _ -> Maybe.map cancel) model, Cmd.none )

        Save bannerId maybeResult ->
            case gacha.cardTypeEditor of
                Just editor ->
                    case maybeResult of
                        Api.Finish result ->
                            let
                                ( maybeCardType, state ) =
                                    editor.save |> Api.handleActionResult result

                                updateCardType id cardType cardTypes =
                                    if cardTypes |> AssocList.keys |> List.member id then
                                        cardTypes |> AssocList.replace id cardType

                                    else
                                        cardTypes |> AssocList.insertAtEnd id cardType

                                updateCardTypes =
                                    case maybeCardType of
                                        Just ( cardTypeId, cardType ) ->
                                            Api.updateIdDataValue bannerId (updateCardType cardTypeId cardType)

                                        Nothing ->
                                            identity

                                updatedEditor =
                                    if maybeCardType == Nothing then
                                        Just { editor | save = state }

                                    else
                                        Just { editor | open = False }
                            in
                            ( { model
                                | gacha =
                                    { gacha
                                        | editableCardTypes = gacha.editableCardTypes |> updateCardTypes
                                        , cardTypeEditor = updatedEditor
                                    }
                              }
                            , Cmd.none
                            )

                        Api.Start ->
                            let
                                { remove, edit, add } =
                                    CreditEditor.toChanges editor.creditEditor

                                ( path, extra ) =
                                    case editor.id of
                                        Just id ->
                                            ( Api.DetailedCardType id
                                            , \v ->
                                                [ ( "version", v |> JsonE.int )
                                                , ( "removeCredits", remove )
                                                , ( "editCredits", edit )
                                                , ( "addCredits", add )
                                                ]
                                            )

                                        Nothing ->
                                            ( Api.CardTypesWithCards
                                            , \_ -> [ ( "credits", add ) ]
                                            )

                                encode { name, description, image, rarity, layout, retired, version } =
                                    [ [ ( "name", name |> JsonE.string )
                                      , ( "description", description |> JsonE.string )
                                      , ( "image", image |> JsonE.string )
                                      , ( "rarity", rarity |> Rarity.encodeId )
                                      , ( "layout", layout |> Card.encodeLayout )
                                      , ( "retired", retired |> JsonE.bool )
                                      ]
                                    , extra version
                                    ]
                                        |> List.concat
                                        |> JsonE.object

                                ( save, cmd ) =
                                    { path = path |> Api.SpecificBanner bannerId |> Api.Banners |> Api.Gacha
                                    , body = encode editor.cardType
                                    , wrap = Api.Finish >> Save bannerId >> wrap
                                    , decoder = CardType.editableWithIdDecoder
                                    }
                                        |> Api.post model.origin
                                        |> Api.doAction editor.save
                            in
                            ( { model | gacha = { gacha | cardTypeEditor = Just { editor | save = save } } }
                            , cmd
                            )

                Nothing ->
                    ( model, Cmd.none )

        SetName name ->
            let
                edit _ _ ({ cardType } as editor) =
                    { editor | cardType = { cardType | name = name } }
            in
            ( updateEditorEdit edit model, Cmd.none )

        SetDescription description ->
            let
                edit _ _ ({ cardType } as editor) =
                    { editor | cardType = { cardType | description = description } }
            in
            ( updateEditorEdit edit model, Cmd.none )

        SetImage uploaderMsg ->
            let
                edit ({ cardType } as editor) =
                    let
                        ( uploader, uploaderCmd ) =
                            Uploader.update (SetImage >> wrap)
                                uploaderMsg
                                model
                                (imageUploaderModel editor.cardType.layout)
                                editor.imageUploader
                    in
                    ( Just
                        { editor
                            | imageUploader = uploader
                            , cardType = { cardType | image = uploader |> Uploader.toUrl }
                        }
                    , uploaderCmd
                    )

                ( updatedCardTypeEditor, cmd ) =
                    gacha.cardTypeEditor |> Maybe.map edit |> Maybe.withDefault ( Nothing, Cmd.none )
            in
            ( { model | gacha = { gacha | cardTypeEditor = updatedCardTypeEditor } }
            , cmd
            )

        SetRarity maybeRarity ->
            case maybeRarity of
                Just rarity ->
                    let
                        edit _ _ ({ cardType } as editor) =
                            { editor | cardType = { cardType | rarity = rarity } }
                    in
                    ( updateEditorEdit edit model, Cmd.none )

                Nothing ->
                    ( model, Cmd.none )

        SetLayout maybeLayout ->
            case maybeLayout of
                Just layout ->
                    let
                        edit _ _ ({ cardType } as editor) =
                            { editor | cardType = { cardType | layout = layout } }
                    in
                    ( updateEditorEdit edit model, Cmd.none )

                Nothing ->
                    ( model, Cmd.none )

        SetRetired retired ->
            let
                edit _ _ ({ cardType } as editor) =
                    { editor | cardType = { cardType | retired = retired } }
            in
            ( updateEditorEdit edit model, Cmd.none )

        EditCredit creditEditorMsg ->
            case model.gacha.cardTypeEditor of
                Just editor ->
                    let
                        ( creditEditor, cmd ) =
                            editor.creditEditor
                                |> CreditEditor.update (EditCredit >> wrap)
                                    model
                                    creditEditorMsg

                        updatedGacha =
                            { gacha
                                | cardTypeEditor =
                                    Just { editor | creditEditor = creditEditor }
                            }
                    in
                    ( { model | gacha = updatedGacha }, cmd )

                Nothing ->
                    ( model, Cmd.none )


nameValidator : Validator EditableCardType
nameValidator =
    Validator.fromPredicate "Name must not be empty." (.name >> String.isEmpty)


imageValidator : Validator EditableCardType
imageValidator =
    Validator.fromPredicate "Image must not be empty." (.image >> String.isEmpty)


descriptionValidator : Validator EditableCardType
descriptionValidator =
    Validator.fromPredicate "Description must not be empty." (.description >> String.isEmpty)


rarityValidator : Gacha.Context -> Validator EditableCardType
rarityValidator context =
    Rarity.validator context |> Validator.map (.rarity >> Just)


validator : Gacha.Context -> Validator Editor
validator context =
    Validator.all
        [ nameValidator |> Validator.map .cardType
        , descriptionValidator |> Validator.map .cardType
        , imageValidator |> Validator.map .cardType
        , rarityValidator context |> Validator.map .cardType
        , CreditEditor.validator |> Validator.map .creditEditor
        ]


cardTypeEditor : Gacha.Context -> Maybe Editor -> Html Global.Msg
cardTypeEditor rarityContext maybeEditor =
    let
        cancel =
            Cancel |> wrap

        ( isOpen, content, action ) =
            case maybeEditor of
                Just ({ open, banner, id, cardType, save, imageUploader, creditEditor } as editor) ->
                    let
                        ifNotSaving =
                            Api.ifNotWorking save

                        viewPlaceholder =
                            Card.viewPlaceholder
                                Nothing
                                banner
                                (id |> Maybe.withDefault (CardType.idFromInt 0))
                                { name = cardType.name
                                , description = cardType.description
                                , image = cardType.image
                                , rarity =
                                    ( cardType.rarity
                                    , Gacha.rarityFromContext rarityContext cardType.rarity
                                        |> Maybe.withDefault { name = "" }
                                    )
                                , layout = cardType.layout
                                , retired = False
                                }
                    in
                    ( open
                    , Html.div [ HtmlA.class "side-by-side" ]
                        [ Html.div [ HtmlA.class "fields" ]
                            [ Html.label [ HtmlA.class "switch" ]
                                [ Html.span [] [ Html.text "Retired" ]
                                , Switch.switch (SetRetired >> wrap |> Just |> ifNotSaving)
                                    cardType.retired
                                    |> Switch.view
                                ]
                            , TextField.outlined "Name"
                                (SetName >> wrap |> Just |> ifNotSaving)
                                cardType.name
                                |> TextField.required True
                                |> TextField.view
                            , Validator.view nameValidator cardType
                            , Card.layoutSelector (SetLayout >> wrap |> Just |> ifNotSaving) (Just cardType.layout)
                            , Html.span [] [ Html.text "Image will be scaled based on layout, please choose that first!" ]
                            , Uploader.view (SetImage >> wrap |> Just |> ifNotSaving)
                                (imageUploaderModel cardType.layout)
                                imageUploader
                            , Validator.view imageValidator cardType
                            , Rarity.selector rarityContext
                                (SetRarity >> wrap |> Just |> ifNotSaving)
                                (Just cardType.rarity)
                            , Validator.view (rarityValidator rarityContext) cardType
                            , TextField.outlined "Description"
                                (SetDescription >> wrap |> Just |> ifNotSaving)
                                cardType.description
                                |> TextField.textArea
                                |> TextField.required True
                                |> TextField.view
                            , Validator.view descriptionValidator cardType
                            , CreditEditor.view (EditCredit >> wrap) banner id creditEditor
                            ]
                        , viewPlaceholder
                        ]
                        :: Api.viewAction [] save
                    , Save banner Api.Start
                        |> wrap
                        |> Validator.whenValid (validator rarityContext) editor
                        |> ifNotSaving
                    )

                Nothing ->
                    ( False, [], Nothing )
    in
    Dialog.dialog cancel
        content
        [ Html.span [ HtmlA.class "cancel" ]
            [ Button.text "Cancel"
                |> Button.button (cancel |> Just)
                |> Button.icon [ Icon.times |> Icon.view ]
                |> Button.view
            ]
        , Button.filled "Save"
            |> Button.button action
            |> Button.icon [ Icon.save |> Icon.view ]
            |> Button.view
        ]
        isOpen
        |> Dialog.headline [ Html.text "Edit Card Type" ]
        |> Dialog.attrs
            [ HtmlA.id "card-type-editor"
            , HtmlA.class "dialog-editor"
            ]
        |> Dialog.view


viewCardTypeSummary : Time.Context -> Banner.Id -> ( CardType.Id, EditableCardType ) -> ( String, Html Global.Msg )
viewCardTypeSummary time banner ( id, cardType ) =
    let
        idString =
            id |> CardType.idToInt |> String.fromInt

        field class label value =
            Html.div [ HtmlA.class class ]
                [ Html.span [ HtmlA.class "label" ] [ Html.text label, Html.text ":" ]
                , Html.text " "
                , Html.span [ HtmlA.class "value" ] value
                ]

        retiredIcon =
            if cardType.retired then
                Icon.times

            else
                Icon.check
    in
    ( idString
    , Html.li [ "card-type-" ++ idString |> HtmlA.id ]
        [ Html.div [ HtmlA.class "metadata" ]
            [ field "created" "Created" [ cardType.created |> DateTime.view time Time.Absolute ]
            , field "modified" "Last Modified" [ cardType.modified |> DateTime.view time Time.Absolute ]
            , field "version" "Version" [ cardType.version |> String.fromInt |> Html.text ]
            ]
        , IconButton.icon (Icon.edit |> Icon.view) "Edit"
            |> IconButton.button (id |> Edit banner |> wrap |> Just)
            |> IconButton.attrs [ HtmlA.class "edit" ]
            |> IconButton.view
        , field "id" "Id" [ Html.text idString ]
        , field "active" "Active" [ retiredIcon |> Icon.view ]
        , field "name" "Name" [ Html.text cardType.name ]
        , field "layout" "Layout" [ cardType.layout |> Card.describeLayout |> .name |> Html.text ]
        , field "image"
            "Image"
            [ Html.span [ HtmlA.class "url" ] [ Html.text cardType.image ]
            , Html.img [ HtmlA.title cardType.image, HtmlA.src cardType.image ] []
            ]
        , field "description" "Description" [ Html.text cardType.description ]
        ]
    )


viewRarityStats : Gacha.Context -> EditableCardTypes -> Html msg
viewRarityStats context cardTypes =
    let
        counts =
            cardTypes
                |> AssocList.toList
                |> List.map (\( _, { rarity } ) -> rarity)
                |> AssocList.count

        listItem ( rarity, { name } ) =
            Html.li []
                [ Html.span [ HtmlA.class "rarity" ] [ Html.text name, Html.text ": " ]
                , Html.span [ HtmlA.class "count" ]
                    [ counts
                        |> AssocList.get rarity
                        |> Maybe.withDefault 0
                        |> String.fromInt
                        |> Html.text
                    ]
                ]
    in
    Html.div [ HtmlA.class "rarity-stats" ]
        [ Html.p [] [ Html.text "Cards by rarity in this banner:" ]
        , context
            |> Gacha.raritiesFromContext
            |> AssocList.toList
            |> List.map listItem
            |> Html.ol []
        ]


viewCardTypeSummaries : Time.Context -> Gacha.Context -> Banner.Id -> EditableCardTypes -> List (Html Global.Msg)
viewCardTypeSummaries time rarityContext banner cardTypes =
    [ viewRarityStats rarityContext cardTypes
    , cardTypes
        |> AssocList.toList
        |> List.map (viewCardTypeSummary time banner)
        |> HtmlK.ol [ HtmlA.class "editor card-type-editor" ]
    , Button.text "Add New"
        |> Button.button (Add banner Nothing |> wrap |> Just)
        |> Button.icon [ Icon.plus |> Icon.view ]
        |> Button.view
    ]


viewCardTypesEditor : Parent a -> Page Global.Msg
viewCardTypesEditor { time, gacha } =
    { title = "Edit Card Types"
    , id = "gacha"
    , body =
        [ [ Html.h2 [] [ Html.text "Edit Card Types" ] ]
        , gacha.editableCardTypes
            |> Api.viewIdData Api.viewOrError (viewCardTypeSummaries time gacha.context)
        , [ gacha.cardTypeEditor |> cardTypeEditor gacha.context ]
        ]
            |> List.concat
    }
