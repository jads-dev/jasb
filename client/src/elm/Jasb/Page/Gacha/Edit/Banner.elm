module Jasb.Page.Gacha.Edit.Banner exposing
    ( loadBannersEditor
    , updateBannersEditor
    , viewBannersEditor
    )

import AssocList
import Color
import DragDrop
import FontAwesome as Icon
import FontAwesome.Solid as Icon
import Html exposing (Html)
import Html.Attributes as HtmlA
import Html.Keyed as HtmlK
import Jasb.Api as Api
import Jasb.Api.Action as Api
import Jasb.Api.Data as Api
import Jasb.Api.Path as Api
import Jasb.Editing.Slug as Slug
import Jasb.Editing.Uploader as Uploader
import Jasb.Editing.Validator as Validator exposing (Validator)
import Jasb.Gacha.Banner as Banner exposing (EditableBanner, EditableBanners)
import Jasb.Material as Material
import Jasb.Messages as Global
import Jasb.Page exposing (Page)
import Jasb.Page.Gacha.Edit.Banner.Model exposing (..)
import Jasb.Page.Gacha.Model as Gacha
import Jasb.Page.Gacha.Route as Gacha
import Jasb.Route as Route
import Json.Encode as JsonE
import List.Extra as List
import Material.Button as Button
import Material.Dialog as Dialog
import Material.IconButton as IconButton
import Material.Switch as Switch
import Material.TextField as TextField
import Task
import Time.DateTime as DateTime
import Time.Model as Time
import Util.AssocList as AssocList
import Util.Maybe as Maybe


wrapGacha : Gacha.Msg -> Global.Msg
wrapGacha =
    Global.GachaMsg


wrap : Msg -> Global.Msg
wrap =
    Gacha.EditBanners >> Gacha.EditMsg >> wrapGacha


type alias Parent a =
    { a
        | origin : String
        , time : Time.Context
        , gacha : Gacha.Model
    }


loadBannersEditor : Parent a -> ( Parent a, Cmd Global.Msg )
loadBannersEditor ({ origin, gacha } as model) =
    let
        ( editableBanners, cmd ) =
            Api.get origin
                { path = Api.EditableBanners |> Api.Banners |> Api.Gacha
                , wrap = Load >> wrap
                , decoder = Banner.editableBannersDecoder
                }
                |> Api.getData gacha.editableBanners
    in
    ( { model | gacha = { gacha | editableBanners = editableBanners } }, cmd )


updateEditor : (Parent a -> Gacha.Model -> Maybe Editor -> Maybe Editor) -> Parent a -> Parent a
updateEditor doUpdate ({ gacha } as model) =
    { model | gacha = { gacha | bannerEditor = gacha.bannerEditor |> doUpdate model model.gacha } }


updateEditorEdit : (Parent a -> Gacha.Model -> Editor -> Editor) -> Parent a -> Parent a
updateEditorEdit doUpdate =
    let
        edit model gacha editor =
            editor |> Maybe.map (doUpdate model gacha)
    in
    updateEditor edit


updateBannersEditor : Msg -> Parent a -> ( Parent a, Cmd Global.Msg )
updateBannersEditor msg ({ gacha } as model) =
    case msg of
        Load response ->
            ( { model
                | gacha =
                    { gacha
                        | editableBanners =
                            gacha.editableBanners |> Api.updateData response
                    }
              }
            , Cmd.none
            )

        DragDrop dragDropMsg ->
            let
                ( newDragDrop, drop ) =
                    DragDrop.update dragDropMsg gacha.bannerOrderDragDrop

                updateOrder banners ( bannerId, index ) =
                    let
                        ( before, after ) =
                            banners.order
                                |> List.filter ((/=) bannerId)
                                |> List.splitAt index
                    in
                    { banners | order = List.concat [ before, [ bannerId ], after ] }

                changeEditableBanners banners =
                    drop
                        |> Maybe.map (updateOrder banners)
                        |> Maybe.withDefault banners

                newEditableBanners =
                    gacha.editableBanners |> Api.mapData changeEditableBanners
            in
            ( { model
                | gacha =
                    { gacha
                        | editableBanners = newEditableBanners
                        , bannerOrderDragDrop = newDragDrop
                    }
              }
            , Cmd.none
            )

        Reorder order ->
            case model.gacha.editableBanners |> Api.dataToMaybe of
                Just { banners } ->
                    let
                        fromId id =
                            banners
                                |> AssocList.get id
                                |> Maybe.map (Tuple.pair id)

                        toTuple ( id, { version } ) =
                            [ id |> Banner.encodeId
                            , version |> JsonE.int
                            ]
                                |> JsonE.list identity

                        ( save, cmd ) =
                            Api.post
                                model.origin
                                { path = Api.BannersRoot |> Api.Banners |> Api.Gacha
                                , body =
                                    order
                                        |> List.filterMap fromId
                                        |> JsonE.list toTuple
                                , wrap = Reordered >> wrap
                                , decoder = Banner.editableBannersDecoder
                                }
                                |> Api.doAction gacha.saveBannerOrder
                    in
                    ( { model | gacha = { gacha | saveBannerOrder = save } }
                    , cmd
                    )

                Nothing ->
                    ( model, Cmd.none )

        Reordered result ->
            let
                ( newOrder, save ) =
                    gacha.saveBannerOrder |> Api.handleActionResult result

                replace oldData =
                    newOrder |> Maybe.withDefault oldData

                updatedEditableBanners =
                    gacha.editableBanners |> Api.mapData replace
            in
            ( { model
                | gacha =
                    { gacha
                        | editableBanners = updatedEditableBanners
                        , saveBannerOrder = save
                    }
              }
            , Cmd.none
            )

        Add maybeTime ->
            case maybeTime of
                Just time ->
                    let
                        newBanner =
                            EditableBanner Slug.Auto
                                ""
                                ""
                                ""
                                False
                                "Standard"
                                { background = Color.white, foreground = Color.black }
                                0
                                time
                                time

                        startAdd _ _ _ =
                            Editor True newBanner Uploader.init "" "" Api.initAction |> Just
                    in
                    ( updateEditor startAdd model, Cmd.none )

                Nothing ->
                    ( model
                    , DateTime.getNow |> Task.perform (Just >> Add >> wrap)
                    )

        Edit id ->
            let
                fromBanner banner =
                    Editor True
                        banner
                        (Uploader.fromUrl banner.cover)
                        (Color.toHexStringWithoutAlpha banner.colors.background)
                        (Color.toHexStringWithoutAlpha banner.colors.foreground)
                        Api.initAction

                startEdit _ g _ =
                    g.editableBanners
                        |> Api.dataToMaybe
                        |> Maybe.andThen (.banners >> AssocList.get id)
                        |> Maybe.map fromBanner
            in
            ( updateEditor startEdit model, Cmd.none )

        Cancel ->
            let
                cancel editor =
                    { editor | open = False }
            in
            ( updateEditor (\_ _ -> Maybe.map cancel) model, Cmd.none )

        Save maybeResult ->
            case gacha.bannerEditor of
                Just editor ->
                    case maybeResult of
                        Just result ->
                            let
                                ( maybeBanner, state ) =
                                    editor.save |> Api.handleActionResult result

                                updateBanner { banners, order } =
                                    case maybeBanner of
                                        Just ( id, banner ) ->
                                            if order |> List.member id then
                                                { banners = banners |> AssocList.replace id banner
                                                , order = order
                                                }

                                            else
                                                { banners = banners |> AssocList.insertAtEnd id banner
                                                , order = order ++ [ id ]
                                                }

                                        Nothing ->
                                            { banners = banners, order = order }

                                updatedBanners =
                                    Api.mapData updateBanner

                                updatedEditor =
                                    if maybeBanner == Nothing then
                                        Just { editor | save = state }

                                    else
                                        Just { editor | open = False }
                            in
                            ( { model
                                | gacha =
                                    { gacha
                                        | editableBanners = updatedBanners gacha.editableBanners
                                        , bannerEditor = updatedEditor
                                    }
                              }
                            , Cmd.none
                            )

                        Nothing ->
                            let
                                ( method, extra ) =
                                    case editor.banner.id of
                                        Slug.Locked _ ->
                                            ( Api.post
                                            , \v -> [ ( "version", v |> JsonE.int ) ]
                                            )

                                        _ ->
                                            ( Api.put, \_ -> [] )

                                id =
                                    Slug.resolve Banner.idFromString
                                        editor.banner.name
                                        editor.banner.id

                                encode { name, description, cover, active, type_, colors, version } =
                                    [ [ ( "name", name |> JsonE.string )
                                      , ( "description", description |> JsonE.string )
                                      , ( "cover", cover |> JsonE.string )
                                      , ( "active", active |> JsonE.bool )
                                      , ( "type", type_ |> JsonE.string )
                                      , ( "backgroundColor", colors.background |> Color.encode )
                                      , ( "foregroundColor", colors.foreground |> Color.encode )
                                      , ( "active", active |> JsonE.bool )
                                      ]
                                    , extra version
                                    ]
                                        |> List.concat
                                        |> JsonE.object

                                ( state, cmd ) =
                                    { path = Api.Banner |> Api.SpecificBanner id |> Api.Banners |> Api.Gacha
                                    , body = encode editor.banner
                                    , wrap = Just >> Save >> wrap
                                    , decoder = Banner.editableDecoder
                                    }
                                        |> method model.origin
                                        |> Api.doAction editor.save
                            in
                            ( { model
                                | gacha =
                                    { gacha
                                        | bannerEditor =
                                            Just { editor | save = state }
                                    }
                              }
                            , cmd
                            )

                Nothing ->
                    ( model, Cmd.none )

        SetId id ->
            let
                setSlug =
                    Slug.set Banner.idFromString (id |> Maybe.ifFalse String.isEmpty)

                edit _ _ ({ banner } as editor) =
                    { editor | banner = { banner | id = setSlug banner.id } }
            in
            ( updateEditorEdit edit model, Cmd.none )

        SetName name ->
            let
                edit _ _ ({ banner } as editor) =
                    { editor | banner = { banner | name = name } }
            in
            ( updateEditorEdit edit model, Cmd.none )

        SetDescription description ->
            let
                edit _ _ ({ banner } as editor) =
                    { editor | banner = { banner | description = description } }
            in
            ( updateEditorEdit edit model, Cmd.none )

        SetCover uploaderMsg ->
            let
                edit ({ banner } as editor) =
                    let
                        ( uploader, uploaderCmd ) =
                            Uploader.update (SetCover >> wrap) uploaderMsg model coverUploaderModel editor.coverUploader
                    in
                    ( Just
                        { editor
                            | coverUploader = uploader
                            , banner = { banner | cover = uploader |> Uploader.toUrl }
                        }
                    , uploaderCmd
                    )

                ( updatedBannerEditor, cmd ) =
                    gacha.bannerEditor |> Maybe.map edit |> Maybe.withDefault ( Nothing, Cmd.none )
            in
            ( { model | gacha = { gacha | bannerEditor = updatedBannerEditor } }
            , cmd
            )

        SetActive active ->
            let
                edit _ _ ({ banner } as editor) =
                    { editor | banner = { banner | active = active } }
            in
            ( updateEditorEdit edit model, Cmd.none )

        SetType type_ ->
            let
                edit _ _ ({ banner } as editor) =
                    { editor | banner = { banner | type_ = type_ } }
            in
            ( updateEditorEdit edit model, Cmd.none )

        SetBackground background ->
            let
                edit _ _ ({ banner } as editor) =
                    let
                        newBanner =
                            case Color.fromHexString background of
                                Just color ->
                                    let
                                        colors =
                                            banner.colors

                                        newColors =
                                            { colors | background = color }
                                    in
                                    { banner | colors = newColors }

                                Nothing ->
                                    banner
                    in
                    { editor
                        | banner = newBanner
                        , background = background
                    }
            in
            ( updateEditorEdit edit model, Cmd.none )

        SetForeground foreground ->
            let
                edit _ _ ({ banner } as editor) =
                    let
                        newBanner =
                            case Color.fromHexString foreground of
                                Just color ->
                                    let
                                        colors =
                                            banner.colors

                                        newColors =
                                            { colors | foreground = color }
                                    in
                                    { banner | colors = newColors }

                                Nothing ->
                                    banner
                    in
                    { editor
                        | banner = newBanner
                        , foreground = foreground
                    }
            in
            ( updateEditorEdit edit model, Cmd.none )


nameValidator : Validator EditableBanner
nameValidator =
    Validator.fromPredicate "Name must not be empty." (.name >> String.isEmpty)


coverValidator : Validator EditableBanner
coverValidator =
    Validator.fromPredicate "Cover must not be empty." (.cover >> String.isEmpty)


descriptionValidator : Validator EditableBanner
descriptionValidator =
    Validator.fromPredicate "Description must not be empty." (.description >> String.isEmpty)


validator : Validator EditableBanner
validator =
    Validator.all
        [ nameValidator
        , descriptionValidator
        , coverValidator
        ]


coverUploaderModel : Uploader.Model
coverUploaderModel =
    { label = "Cover"
    , types = [ "image/*" ]
    , path = Api.BannerCoverUpload |> Api.Banners |> Api.Gacha
    , extraParts = []
    }


bannerEditor : Maybe Editor -> Html Global.Msg
bannerEditor maybeEditor =
    let
        cancel =
            Cancel |> wrap

        ( dialogOpen, dialogContent, action ) =
            case maybeEditor of
                Just { open, banner, save, coverUploader, background, foreground } ->
                    let
                        ifNotSaving =
                            Api.ifNotWorking save
                    in
                    ( open
                    , [ Html.div [ HtmlA.class "fields" ]
                            [ Slug.view Banner.idFromString Banner.idToString (SetId >> wrap |> Just |> ifNotSaving) banner.name banner.id
                            , Html.label [ HtmlA.class "switch" ]
                                [ Html.span [] [ Html.text "Is Active" ]
                                , Switch.switch
                                    (SetActive >> wrap |> Just |> ifNotSaving)
                                    banner.active
                                    |> Switch.view
                                ]
                            , TextField.outlined "Name"
                                (SetName >> wrap |> Just |> ifNotSaving)
                                banner.name
                                |> TextField.required True
                                |> TextField.view
                            , Validator.view nameValidator banner
                            , Uploader.view (SetCover >> wrap |> Just |> ifNotSaving) coverUploaderModel coverUploader
                            , Validator.view coverValidator banner
                            , Color.picker "Background Color" (SetBackground >> wrap |> Just |> ifNotSaving) background
                            , Color.picker "Foreground Color" (SetForeground >> wrap |> Just |> ifNotSaving) foreground
                            , TextField.outlined "Description"
                                (SetDescription >> wrap |> Just)
                                banner.description
                                |> TextField.textArea
                                |> TextField.required True
                                |> TextField.view
                            , Validator.view descriptionValidator banner
                            ]
                      ]
                    , Save Nothing |> wrap |> Validator.whenValid validator banner |> ifNotSaving
                    )

                Nothing ->
                    ( False, [], Nothing )

        controls =
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
    in
    Dialog.dialog cancel dialogContent controls dialogOpen
        |> Dialog.headline [ Html.text "Edit Banner" ]
        |> Dialog.attrs [ HtmlA.id "banner-editor", HtmlA.class "dialog-editor" ]
        |> Dialog.view


viewBanner : Time.Context -> List Banner.Id -> Gacha.Model -> Int -> ( Banner.Id, EditableBanner ) -> ( String, Html Global.Msg )
viewBanner time order { bannerOrderDragDrop } index ( id, banner ) =
    let
        idString =
            id |> Banner.idToString

        dragging =
            if DragDrop.getDragId bannerOrderDragDrop == Just id then
                [ HtmlA.class "dragging" ]

            else
                []

        droppable =
            case DragDrop.getDragId bannerOrderDragDrop of
                Just draggingId ->
                    if (order |> List.elemIndex draggingId) == Just index then
                        []

                    else
                        HtmlA.class "droppable" :: DragDrop.droppable (DragDrop >> wrap) index

                Nothing ->
                    []

        hover =
            if DragDrop.getDropId bannerOrderDragDrop == Just index then
                [ HtmlA.class "hover" ]

            else
                []

        attrs =
            [ [ "banner-" ++ idString |> HtmlA.id ]
            , dragging
            , DragDrop.draggable (DragDrop >> wrap) id
            , droppable
            , hover
            ]
                |> List.concat

        field class label value =
            Html.div [ HtmlA.class class ]
                [ Html.span [ HtmlA.class "label" ] [ Html.text label, Html.text ":" ]
                , Html.text " "
                , Html.span [ HtmlA.class "value" ] value
                ]

        activeIcon =
            if banner.active then
                Icon.check

            else
                Icon.times
    in
    ( idString
    , Html.li attrs
        [ Html.div [ HtmlA.class "grip" ] [ Icon.gripLines |> Icon.view ]
        , Html.div [ HtmlA.class "metadata" ]
            [ field "created" "Created" [ banner.created |> DateTime.view time Time.Absolute ]
            , field "modified" "Last Modified" [ banner.modified |> DateTime.view time Time.Absolute ]
            , field "version" "Version" [ banner.version |> String.fromInt |> Html.text ]
            ]
        , Html.div [ HtmlA.class "edit" ]
            [ Button.text "Edit Card Types"
                |> Material.buttonLink Global.ChangeUrl (Gacha.CardType id |> Gacha.Edit |> Route.Gacha)
                |> Button.icon [ Icon.diamond |> Icon.view ]
                |> Button.view
            , IconButton.icon (Icon.edit |> Icon.view) "Edit"
                |> IconButton.button (id |> Edit |> wrap |> Just)
                |> IconButton.view
            ]
        , field "slug" "Slug" [ Html.text idString ]
        , field "active" "Active" [ activeIcon |> Icon.view ]
        , field "name" "Name" [ Html.text banner.name ]
        , field "cover"
            "Cover"
            [ Html.span [ HtmlA.class "url" ] [ Html.text banner.cover ]
            , Html.img [ HtmlA.title banner.cover, HtmlA.src banner.cover ] []
            ]
        , field "description" "Description" [ Html.text banner.description ]
        ]
    )


viewBanners : Time.Context -> Gacha.Model -> EditableBanners -> List (Html Global.Msg)
viewBanners time model { banners, order } =
    let
        reorder =
            Reorder order
                |> wrap
                |> Maybe.when (order /= AssocList.keys banners)
                |> Api.ifNotWorking model.saveBannerOrder
    in
    [ order
        |> List.filterMap (\id -> AssocList.get id banners |> Maybe.map (\b -> ( id, b )))
        |> List.indexedMap (viewBanner time order model)
        |> HtmlK.ol [ HtmlA.class "banner-editor editor" ]
    , Button.text "Save Order"
        |> Button.button reorder
        |> Button.icon [ Icon.save |> Icon.view |> Api.orSpinner model.saveBannerOrder ]
        |> Button.view
    , Button.text "Add New"
        |> Button.button (Add Nothing |> wrap |> Just)
        |> Button.icon [ Icon.plus |> Icon.view ]
        |> Button.view
    ]


viewBannersEditor : Parent a -> Page Global.Msg
viewBannersEditor { time, gacha } =
    { title = "Edit Banners"
    , id = "gacha"
    , body =
        [ [ Html.h2 [] [ Html.text "Edit Banners" ] ]
        , gacha.editableBanners |> Api.viewData Api.viewOrError (viewBanners time gacha)
        , [ bannerEditor gacha.bannerEditor ]
        ]
            |> List.concat
    }
