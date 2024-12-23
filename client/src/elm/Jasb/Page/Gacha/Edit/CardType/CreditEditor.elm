module Jasb.Page.Gacha.Edit.CardType.CreditEditor exposing
    ( Model
    , Msg(..)
    , init
    , initFromExisting
    , toChanges
    , update
    , validator
    , view
    )

import AssocList
import FontAwesome as Icon
import FontAwesome.Solid as Icon
import Html exposing (Html)
import Html.Attributes as HtmlA
import Html.Keyed as HtmlK
import Jasb.Api as Api
import Jasb.Api.Data as Api
import Jasb.Api.Model as Api
import Jasb.Api.Path as Api
import Jasb.Editing.UserSelector as UserSelector
import Jasb.Editing.Validator as Validator exposing (Validator)
import Jasb.Gacha.Banner as Banner
import Jasb.Gacha.Card as Card exposing (Card)
import Jasb.Gacha.CardType as CardType
import Jasb.Gacha.Credits as Credits
import Jasb.User.Model as User
import Json.Encode as JsonE
import Material.Button as Button
import Material.IconButton as IconButton
import Material.Switch as Switch
import Material.TextField as TextField
import Time.Model as Time
import Util.AssocList as AssocList


type alias Parent a =
    { a
        | origin : String
        , time : Time.Context
    }


type ItemMsg
    = SetJasbUser Bool
    | SetName String
    | UserSelectorMsg UserSelector.Msg
    | SetReason String
    | GiftSelfMade Banner.Id CardType.Id User.Id (Api.Process ( Card.Id, Card ))


type Msg
    = Add
    | EditItem EditId ItemMsg
    | Remove EditId


type alias EditId =
    Int


type alias Item =
    { jasbUser : Bool
    , removed : Bool
    , name : String
    , user : UserSelector.Model
    , reason : String
    , giftedCard : Api.Data ( Card.Id, Card )
    , source : Maybe { id : Credits.Id, credit : Credits.EditableCredit }
    }


type alias Model =
    { items : AssocList.Dict EditId Item
    , nextEditId : EditId
    }


init : Model
init =
    { items = AssocList.empty
    , nextEditId = 0
    }


initFromExisting : AssocList.Dict Credits.Id Credits.EditableCredit -> Model
initFromExisting credits =
    let
        fromSource index ( id, credit ) =
            ( index, initItemFromExisting id credit )
    in
    { items =
        credits
            |> AssocList.toList
            |> List.indexedMap fromSource
            |> List.reverse
            |> AssocList.fromList
    , nextEditId = AssocList.size credits
    }


initItem : Item
initItem =
    { jasbUser = True
    , removed = False
    , name = ""
    , user = UserSelector.init
    , reason = ""
    , giftedCard = Api.initData
    , source = Nothing
    }


initItemFromExisting : Credits.Id -> Credits.EditableCredit -> Item
initItemFromExisting creditId credit =
    let
        fromValues givenId givenAvatar =
            UserSelector.initFromExisting
                { id = givenId
                , user =
                    { name = credit.name
                    , discriminator = credit.discriminator
                    , avatar = givenAvatar
                    }
                }

        user =
            Maybe.map2 fromValues credit.id credit.avatar
                |> Maybe.withDefault UserSelector.init
    in
    { jasbUser = user.selected /= Nothing
    , removed = False
    , name = credit.name
    , user = user
    , reason = credit.reason
    , giftedCard = Api.initData
    , source = Just { id = creditId, credit = credit }
    }


updateItem : (ItemMsg -> msg) -> Parent a -> ItemMsg -> Item -> ( Item, Cmd msg )
updateItem wrap parent msg model =
    case msg of
        SetName name ->
            ( { model | name = name, user = model.user |> UserSelector.deselect }
            , Cmd.none
            )

        UserSelectorMsg userSelectorMsg ->
            let
                ( user, cmd ) =
                    UserSelector.update (UserSelectorMsg >> wrap)
                        parent
                        userSelectorMsg
                        model.user
            in
            ( { model | user = user }, cmd )

        SetReason reason ->
            ( { model | reason = reason }, Cmd.none )

        SetJasbUser jasbUser ->
            ( { model | jasbUser = jasbUser }, Cmd.none )

        GiftSelfMade bannerId cardTypeId giftToUser process ->
            case process of
                Api.Start ->
                    let
                        ( giftedCard, cmd ) =
                            Api.post parent.origin
                                { path =
                                    Api.GiftCardType cardTypeId
                                        |> Api.SpecificBanner bannerId
                                        |> Api.Banners
                                        |> Api.Gacha
                                , body =
                                    [ ( "user", giftToUser |> User.encodeId ) ]
                                        |> JsonE.object
                                , decoder = Card.withIdDecoder
                                , wrap = Api.Finish >> GiftSelfMade bannerId cardTypeId giftToUser >> wrap
                                }
                                |> Api.getData model.giftedCard
                    in
                    ( { model | giftedCard = giftedCard }, cmd )

                Api.Finish result ->
                    let
                        giftedCard =
                            model.giftedCard |> Api.updateData result
                    in
                    ( { model | giftedCard = giftedCard }, Cmd.none )


update : (Msg -> msg) -> Parent a -> Msg -> Model -> ( Model, Cmd msg )
update wrap parent msg model =
    case msg of
        Add ->
            ( { model
                | items = model.items |> AssocList.insertAtEnd model.nextEditId initItem
                , nextEditId = model.nextEditId + 1
              }
            , Cmd.none
            )

        EditItem id itemMsg ->
            case model.items |> AssocList.get id of
                Just item ->
                    let
                        ( updatedItem, cmd ) =
                            updateItem (EditItem id >> wrap) parent itemMsg item
                    in
                    ( { model | items = model.items |> AssocList.replace id updatedItem }
                    , cmd
                    )

                Nothing ->
                    ( model, Cmd.none )

        Remove id ->
            let
                setRemoved item =
                    { item | removed = True }

                items =
                    model.items |> AssocList.update id (Maybe.map setRemoved)
            in
            ( { model | items = items }
            , Cmd.none
            )


reasonValidator : Validator Item
reasonValidator =
    Validator.fromPredicate "Reason must not be empty." (.reason >> String.isEmpty)


nameOrUserValidator : Validator Item
nameOrUserValidator =
    let
        pick { jasbUser } =
            if jasbUser then
                Validator.fromPredicate "Must select a user." (.user >> .selected >> (==) Nothing)

            else
                Validator.fromPredicate "Name must not be empty." (.name >> String.isEmpty)
    in
    Validator.dependent pick


itemValidator : Validator Item
itemValidator =
    Validator.all
        [ reasonValidator
        , nameOrUserValidator
        ]


validator : Validator Model
validator =
    let
        items =
            .items >> AssocList.values >> List.filter (.removed >> not)
    in
    Validator.list itemValidator |> Validator.map items


viewItem : (ItemMsg -> msg) -> msg -> EditId -> Banner.Id -> Maybe CardType.Id -> Item -> Html msg
viewItem wrap remove editId bannerId maybeCardTypeId ({ jasbUser, name, user, reason, giftedCard } as item) =
    let
        userEditor =
            if jasbUser then
                UserSelector.view (UserSelectorMsg >> wrap)
                    (String.fromInt editId)
                    True
                    user

            else
                TextField.outlined "Name"
                    (SetName >> wrap |> Just)
                    name
                    |> Validator.textFieldError nameOrUserValidator item
                    |> TextField.attrs [ HtmlA.class "user-name" ]
                    |> TextField.view

        giftSelfMade =
            if jasbUser then
                let
                    gifted =
                        giftedCard |> Api.isLoaded

                    actionResolved =
                        if gifted then
                            Nothing

                        else
                            let
                                action { id } cardTypeId =
                                    GiftSelfMade
                                        bannerId
                                        cardTypeId
                                        id
                                        Api.Start
                                        |> wrap
                            in
                            Maybe.map2 action user.selected maybeCardTypeId
                                |> Api.ifNotDataLoading giftedCard

                    icon =
                        if gifted then
                            Icon.check |> Icon.view

                        else
                            Icon.gift |> Icon.view
                in
                (IconButton.icon icon
                    "Gift Self-Made Card"
                    |> IconButton.button actionResolved
                    |> IconButton.attrs [ HtmlA.class "gift-button" ]
                    |> IconButton.view
                )
                    :: Api.viewErrorIfFailed giftedCard

            else
                []
    in
    [ [ IconButton.icon (Icon.view Icon.trash) "Remove"
            |> IconButton.button (remove |> Just)
            |> IconButton.attrs [ HtmlA.class "remove" ]
            |> IconButton.view
      , TextField.outlined "Reason"
            (SetReason >> wrap |> Just)
            reason
            |> TextField.required True
            |> Validator.textFieldError reasonValidator item
            |> TextField.attrs [ HtmlA.class "reason" ]
            |> TextField.view
      , Html.label [ HtmlA.class "switch user-switch" ]
            [ Html.span [] [ Html.text "JASB User" ]
            , Switch.switch
                (SetJasbUser >> wrap |> Just)
                jasbUser
                |> Switch.view
            ]
      , userEditor
      ]
    , giftSelfMade
    ]
        |> List.concat
        |> Html.li []


view : (Msg -> msg) -> Banner.Id -> Maybe CardType.Id -> Model -> Html msg
view wrap bannerId maybeCardTypeId { items } =
    let
        wrappedViewItem ( id, item ) =
            if item.removed then
                Nothing

            else
                Just
                    ( id |> String.fromInt
                    , item |> viewItem (EditItem id >> wrap) (Remove id |> wrap) id bannerId maybeCardTypeId
                    )

        renderedItems =
            items
                |> AssocList.toList
                |> List.filterMap wrappedViewItem
                |> HtmlK.ul []
    in
    Html.div [ HtmlA.class "credit-editor" ]
        [ Html.h3 [] [ Html.text "Credits" ]
        , renderedItems
        , Button.text "Add Credit"
            |> Button.button (Add |> wrap |> Just)
            |> Button.icon [ Icon.plus |> Icon.view ]
            |> Button.view
        ]


toChanges : Model -> { remove : JsonE.Value, edit : JsonE.Value, add : JsonE.Value }
toChanges { items } =
    let
        idAndVersion { id, credit } =
            [ ( "id", Credits.encodeId id )
            , ( "version", JsonE.int credit.version )
            ]

        add { reason, name, user } =
            let
                userItem { id } =
                    [ ( "user", User.encodeId id ) ]

                credited =
                    user.selected
                        |> Maybe.map userItem
                        |> Maybe.withDefault [ ( "name", JsonE.string name ) ]
                        |> JsonE.object
            in
            [ ( "reason", JsonE.string reason ), ( "credited", credited ) ]

        edit { credit } new =
            let
                credited =
                    case new.user.selected of
                        Just { id } ->
                            if credit.id /= Just id then
                                [ ( "credited", JsonE.object [ ( "user", User.encodeId id ) ] ) ]

                            else
                                []

                        Nothing ->
                            if credit.name /= new.name then
                                [ ( "credited", JsonE.object [ ( "name", JsonE.string new.name ) ] ) ]

                            else
                                []

                reason =
                    if credit.reason /= new.reason then
                        [ ( "reason", JsonE.string new.reason ) ]

                    else
                        []
            in
            List.append reason credited

        foldFunction item ( removes, edits, adds ) =
            if item.removed then
                case item.source of
                    Just source ->
                        ( (idAndVersion source |> JsonE.object) :: removes
                        , edits
                        , adds
                        )

                    Nothing ->
                        ( removes, edits, adds )

            else
                case item.source of
                    Just source ->
                        case edit source item of
                            [] ->
                                ( removes, edits, adds )

                            changes ->
                                ( removes
                                , ([ idAndVersion source, changes ]
                                    |> List.concat
                                    |> JsonE.object
                                  )
                                    :: edits
                                , adds
                                )

                    Nothing ->
                        ( removes
                        , edits
                        , (add item |> JsonE.object)
                            :: adds
                        )

        ( r, e, a ) =
            items |> AssocList.values |> List.foldl foldFunction ( [], [], [] )
    in
    { remove = r |> JsonE.list identity
    , edit = e |> JsonE.list identity
    , add = a |> JsonE.list identity
    }
