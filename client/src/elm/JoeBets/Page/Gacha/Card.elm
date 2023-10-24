module JoeBets.Page.Gacha.Card exposing
    ( ManageOrView(..)
    , view
    , viewCardTypes
    , viewCardTypesWithCards
    , viewCards
    , viewDetailedCard
    , viewDetailedCardDialog
    , viewDetailedCardType
    , viewDetailedCardTypeDialog
    , viewHighlight
    , viewPlaceholder
    )

import AssocList
import DragDrop
import EverySet
import FontAwesome as Icon
import FontAwesome.Regular as RegularIcon
import FontAwesome.Solid as Icon
import Html exposing (Html)
import Html.Attributes as HtmlA
import Html.Events as HtmlE
import Html.Keyed as HtmlK
import JoeBets.Api.Action as Api
import JoeBets.Api.Data as Api
import JoeBets.Api.Error as Api
import JoeBets.Api.IdData as Api
import JoeBets.Components.GachaCard as GachaCard
import JoeBets.Gacha.Banner as Banner
import JoeBets.Gacha.Card as Card exposing (Card)
import JoeBets.Gacha.CardType as CardType exposing (CardType)
import JoeBets.Gacha.CardType.WithCards as CardType
import JoeBets.Gacha.Credits as Credits
import JoeBets.Gacha.Quality as Quality
import JoeBets.Messages as Global
import JoeBets.Page.Gacha.Card.Model exposing (..)
import JoeBets.Page.Gacha.Collection.Model as Collection
import JoeBets.Page.Gacha.Model as Gacha
import JoeBets.User as User
import JoeBets.User.Model as User
import Json.Decode as JsonD
import List
import List.Extra as List
import Material.Button as Button
import Material.Dialog as Dialog
import Material.IconButton as IconButton
import Material.TextField as TextField
import Util.Maybe as Maybe


wrap : Gacha.Msg -> Global.Msg
wrap =
    Global.GachaMsg


wrapCollection : Collection.Msg -> Global.Msg
wrapCollection =
    Global.CollectionMsg


qualityClass : Quality.Id -> ( String, Bool )
qualityClass qualityId =
    ( qualityId |> Quality.class, True )


type TypeOrIndividual
    = CardType { cardTypeId : CardType.Id }
    | Card { ownerId : User.Id, cardId : Card.Id, individual : Card.Individual }


viewInternal : Maybe Global.Msg -> List (Html.Attribute Global.Msg) -> Banner.Id -> CardType -> TypeOrIndividual -> Html Global.Msg
viewInternal onClick attrs bannerId cardType typeOrIndividual =
    let
        cardTypeAttrs { name, description, image, rarity, layout, retired } =
            let
                ( rarityId, _ ) =
                    rarity

                retiredAttr =
                    if retired then
                        [ GachaCard.retired ]

                    else
                        []
            in
            List.append
                [ GachaCard.name name
                , GachaCard.description description
                , GachaCard.image image
                , GachaCard.rarity rarityId
                , GachaCard.layout layout
                , GachaCard.banner bannerId
                ]
                retiredAttr

        typeOrIndividualAttrs =
            case typeOrIndividual of
                Card { cardId, individual } ->
                    [ cardId |> Card.cssId |> HtmlA.id
                    , GachaCard.serialNumber cardId
                    , GachaCard.interactive
                    , GachaCard.issueNumber individual.issueNumber
                    , individual.qualities
                        |> AssocList.keys
                        |> GachaCard.qualities
                    ]

                CardType { cardTypeId } ->
                    [ cardTypeId |> CardType.cssId |> HtmlA.id
                    , GachaCard.sample
                    ]

        onClickIfGiven =
            case onClick of
                Just action ->
                    [ HtmlE.onClick action ]

                Nothing ->
                    []
    in
    [ typeOrIndividualAttrs
    , cardTypeAttrs cardType
    , onClickIfGiven
    , attrs
    ]
        |> List.concat
        |> GachaCard.view


view : Maybe Global.Msg -> List (Html.Attribute Global.Msg) -> User.Id -> Banner.Id -> Card.Id -> Card -> Html Global.Msg
view onClick attrs ownerId bannerId cardId card =
    { ownerId = ownerId, cardId = cardId, individual = card.individual }
        |> Card
        |> viewInternal onClick attrs bannerId card.cardType


viewPlaceholder : Maybe Global.Msg -> Banner.Id -> CardType.Id -> CardType -> Html Global.Msg
viewPlaceholder onClick bannerId cardTypeId cardType =
    { cardTypeId = cardTypeId }
        |> CardType
        |> viewInternal onClick [] bannerId cardType


viewWithEditor : Collection.ManageContext -> Maybe Global.Msg -> User.Id -> Banner.Id -> Card.Id -> Card -> Html Global.Msg
viewWithEditor manageContext onClick ownerId bannerId cardId card =
    let
        edit =
            let
                isHighlighted =
                    manageContext.highlighted |> EverySet.member cardId

                highlightAction =
                    Collection.SetCardHighlighted
                        ownerId
                        bannerId
                        cardId
                        (isHighlighted |> not)
                        |> wrapCollection
                        |> Just

                highlightIcon =
                    if isHighlighted then
                        Icon.star

                    else
                        RegularIcon.star

                recycleAction =
                    [ IconButton.icon (Icon.recycle |> Icon.view)
                        "Recycle"
                        |> IconButton.button
                            (Collection.RecycleCard
                                ownerId
                                bannerId
                                cardId
                                Collection.AskConfirmRecycle
                                |> wrapCollection
                                |> Maybe.whenNot isHighlighted
                            )
                        |> IconButton.view
                    ]

                showcaseAction =
                    [ IconButton.icon (highlightIcon |> Icon.view) "Showcase"
                        |> IconButton.button highlightAction
                        |> IconButton.view
                    ]
            in
            [ Html.ul [ HtmlA.class "card-controls" ]
                [ Html.li [ HtmlA.class "showcase" ] showcaseAction
                , Html.li [ HtmlA.class "recycle" ] recycleAction
                ]
            ]
    in
    Html.div [ HtmlA.class "card-container" ]
        (view onClick [] ownerId bannerId cardId card :: edit)


viewMaybeEditor : Maybe Collection.ManageContext -> Maybe Global.Msg -> User.Id -> Banner.Id -> Card.Id -> Card -> Html Global.Msg
viewMaybeEditor maybeContext onClick =
    case maybeContext of
        Just context ->
            viewWithEditor context onClick

        Nothing ->
            view onClick []


type DetailedTypeOrIndividual
    = DetailedCardType { cardTypeId : CardType.Id }
    | DetailedCard { ownerId : User.Id, cardId : Card.Id, individual : Card.DetailedIndividual }


viewDetailedInternal : Maybe Collection.ManageContext -> Banner.Id -> CardType.Detailed -> DetailedTypeOrIndividual -> Html Global.Msg
viewDetailedInternal maybeContext bannerId cardType individualDetails =
    let
        viewQuality ( qualityId, { quality, description } ) =
            Html.li
                [ HtmlA.classList
                    [ ( "quality", True )
                    , qualityClass qualityId
                    ]
                ]
                [ Html.span [ HtmlA.class "name" ] [ Html.text quality.name ]
                , Html.span [ HtmlA.class "description" ] [ Html.text description ]
                ]

        viewCredit credit =
            let
                credited =
                    case Credits.userOrName credit of
                        Credits.User summaryWithId ->
                            User.viewLink User.Full summaryWithId.id summaryWithId.user

                        Credits.Name name ->
                            Html.text name
            in
            Html.li [ HtmlA.class "credit" ]
                [ Html.span [ HtmlA.class "reason" ] [ Html.text credit.reason ]
                , Html.span [ HtmlA.class "credited" ] [ credited ]
                ]

        bannerDescription =
            let
                retired =
                    cardType.cardType.retired

                ( _, banner ) =
                    cardType.banner

                content =
                    if retired || not banner.active then
                        [ Html.text "This card was available in the "
                        , Html.text banner.name
                        , Html.text " banner, and is now retired."
                        ]

                    else
                        [ Html.text "This card is available in the "
                        , Html.text banner.name
                        , Html.text " banner."
                        ]
            in
            Html.div [ HtmlA.class "banner-description" ] content

        ( card, qualities ) =
            case individualDetails of
                DetailedCard { ownerId, cardId, individual } ->
                    ( { cardType = cardType
                      , individual = individual
                      }
                        |> Card.fromDetailed
                        |> viewMaybeEditor maybeContext Nothing ownerId bannerId cardId
                    , if AssocList.isEmpty individual.qualities then
                        []

                      else
                        [ Html.h3 [] [ Html.text "Qualities" ]
                        , individual.qualities
                            |> AssocList.toList
                            |> List.map viewQuality
                            |> Html.ul [ HtmlA.class "qualities" ]
                        ]
                    )

                DetailedCardType { cardTypeId } ->
                    ( cardType
                        |> CardType.fromDetailed
                        |> viewPlaceholder Nothing bannerId cardTypeId
                    , []
                    )

        credits =
            if List.isEmpty cardType.credits then
                []

            else
                [ Html.h3 [] [ Html.text "Credits" ]
                , cardType.credits
                    |> List.map viewCredit
                    |> Html.ul [ HtmlA.class "credits" ]
                ]
    in
    [ [ card
      , bannerDescription
      ]
    , qualities
    , credits
    ]
        |> List.concat
        |> Html.div [ HtmlA.class "card-details" ]


viewDetailedCard : Maybe Collection.ManageContext -> User.Id -> Banner.Id -> Card.Id -> Card.Detailed -> Html Global.Msg
viewDetailedCard maybeContext ownerId bannerId cardId card =
    { ownerId = ownerId, cardId = cardId, individual = card.individual }
        |> DetailedCard
        |> viewDetailedInternal maybeContext bannerId card.cardType


viewDetailedCardType : Banner.Id -> CardType.Id -> CardType.Detailed -> Html Global.Msg
viewDetailedCardType bannerId cardTypeId cardType =
    { cardTypeId = cardTypeId }
        |> DetailedCardType
        |> viewDetailedInternal Nothing bannerId cardType


viewDetailedCardDialog : Maybe Collection.ManageContext -> Gacha.Model -> Html Global.Msg
viewDetailedCardDialog maybeContext { detailedCard } =
    let
        close =
            Gacha.HideDetailedCard |> wrap

        viewDetailedData { ownerId, bannerId, cardId } card =
            [ viewDetailedCard maybeContext ownerId bannerId cardId card ]

        viewGiven ( pointer, card ) =
            card |> Api.viewData Api.viewOrError (viewDetailedData pointer)

        data =
            detailedCard.detail |> Api.idDataToData
    in
    Dialog.dialog
        close
        (data |> Maybe.map viewGiven |> Maybe.withDefault [])
        [ Button.text "Close"
            |> Button.icon [ Icon.times |> Icon.view ]
            |> Button.button (Just close)
            |> Button.view
        ]
        detailedCard.open
        |> Dialog.headline [ Html.text "Card Details" ]
        |> Dialog.attrs [ HtmlA.class "card-detail-dialog" ]
        |> Dialog.view


viewDetailedCardTypeDialog : Gacha.Model -> Html Global.Msg
viewDetailedCardTypeDialog { detailedCardType } =
    let
        close =
            Gacha.HideDetailedCardType |> wrap

        viewDetailedData { bannerId, cardTypeId } cardType =
            [ viewDetailedCardType bannerId cardTypeId cardType ]

        viewGiven ( pointer, cardType ) =
            cardType |> Api.viewData Api.viewOrError (viewDetailedData pointer)

        data =
            detailedCardType.detail |> Api.idDataToData
    in
    Dialog.dialog
        close
        (data |> Maybe.map viewGiven |> Maybe.withDefault [])
        [ Button.text "Close"
            |> Button.icon [ Icon.times |> Icon.view ]
            |> Button.button (Just close)
            |> Button.view
        ]
        detailedCardType.open
        |> Dialog.headline [ Html.text "Card Details" ]
        |> Dialog.attrs [ HtmlA.class "card-detail-dialog" ]
        |> Dialog.view


internalViewCards : Maybe (Card.Id -> Global.Msg) -> (Card.Id -> List (Html.Attribute Global.Msg)) -> User.Id -> Banner.Id -> Card.Cards -> List ( String, Html Global.Msg )
internalViewCards onClick attrs userId bannerId =
    let
        viewListItem ( cardId, card ) =
            ( Card.cssId cardId
            , Html.li []
                [ view
                    (onClick |> Maybe.map ((|>) cardId))
                    (attrs cardId)
                    userId
                    bannerId
                    cardId
                    card
                ]
            )
    in
    AssocList.toList >> List.map viewListItem


viewCards : Maybe (Card.Id -> Global.Msg) -> (Card.Id -> List (Html.Attribute Global.Msg)) -> User.Id -> Banner.Id -> Card.Cards -> Html Global.Msg
viewCards onClick attrs userId bannerId cards =
    if AssocList.size cards > 0 then
        internalViewCards onClick attrs userId bannerId cards |> HtmlK.ul [ HtmlA.class "cards" ]

    else
        Html.p [ HtmlA.class "cards empty" ] [ Icon.ghost |> Icon.view, Html.text "This user has no cards yet." ]


type ManageOrView
    = Manage (Maybe Collection.ManageContext)
    | View (Maybe (User.Id -> Banner.Id -> Card.Id -> Global.Msg))


viewHighlight : ManageOrView -> Collection.Model -> User.Id -> Collection.LocalOrderHighlights -> Int -> ( Card.Id, ( Banner.Id, Card.Highlighted ) ) -> ( String, Html Global.Msg )
viewHighlight manageOrView model ownerId highlights index ( cardId, ( bannerId, { card, highlight } ) ) =
    let
        ( maybeContext, onClick ) =
            case manageOrView of
                Manage mc ->
                    ( mc, Nothing )

                View oc ->
                    ( Nothing, oc )

        fillDetailed id f =
            f ownerId bannerId id

        viewedCard =
            viewMaybeEditor maybeContext
                (onClick |> Maybe.map (fillDetailed cardId))
                ownerId
                bannerId
                cardId
                card

        viewEditor owner existingMessage =
            let
                editHighlightMessage =
                    Collection.EditHighlightMessage owner bannerId cardId >> wrapCollection

                viewEditButton =
                    [ IconButton.icon (Icon.edit |> Icon.view)
                        "Edit Message"
                        |> IconButton.button (editHighlightMessage (highlight.message |> Maybe.withDefault "" |> Just) |> Just)
                        |> IconButton.view
                    ]
            in
            case model.messageEditor of
                Just editor ->
                    if editor.card == cardId then
                        let
                            cancel =
                                editHighlightMessage Nothing

                            save =
                                Collection.SetHighlightMessage
                                    owner
                                    bannerId
                                    cardId
                                    (editor.message |> Maybe.ifTrue ((/=) ""))
                                    |> wrapCollection

                            onKeyPress pressedKey =
                                if Api.isWorking model.saving then
                                    JsonD.fail "Saving, not monitored."

                                else
                                    case pressedKey of
                                        "Enter" ->
                                            JsonD.succeed save

                                        "Escape" ->
                                            JsonD.succeed cancel

                                        _ ->
                                            JsonD.fail "Not a monitored key."
                        in
                        [ TextField.outlined "Message"
                            (Just >> editHighlightMessage |> Just |> Api.ifNotWorking model.saving)
                            editor.message
                            |> TextField.keyPressAction onKeyPress
                            |> TextField.attrs [ HtmlA.id "highlighted-message-editor" ]
                            |> TextField.error (model.saving |> Api.toMaybeError |> Maybe.map Api.errorToString)
                            |> TextField.view
                        , IconButton.icon (Icon.undo |> Icon.view) "Cancel"
                            |> IconButton.button (cancel |> Just |> Api.ifNotWorking model.saving)
                            |> IconButton.view
                        , IconButton.icon
                            (Api.orSpinner model.saving (Icon.save |> Icon.view))
                            "Save"
                            |> IconButton.button (Api.ifNotWorking model.saving (save |> Just))
                            |> IconButton.view
                        ]

                    else
                        List.append existingMessage viewEditButton

                Nothing ->
                    List.append existingMessage viewEditButton

        messageHtml =
            case highlight.message of
                Just messageString ->
                    let
                        existingMessage =
                            [ Html.p [ HtmlA.class "message" ] [ Html.text messageString ] ]
                    in
                    case maybeContext of
                        Just _ ->
                            viewEditor ownerId existingMessage

                        Nothing ->
                            existingMessage

                Nothing ->
                    case maybeContext of
                        Just _ ->
                            viewEditor ownerId []

                        Nothing ->
                            []

        ( dragAttrs, dropAttrs ) =
            case maybeContext of
                Just { orderEditor } ->
                    let
                        dragId =
                            DragDrop.getDragId orderEditor

                        dragging =
                            if dragId == Just cardId then
                                [ HtmlA.class "dragging" ]

                            else
                                []

                        draggable =
                            DragDrop.draggable
                                (Collection.ReorderHighlights ownerId >> wrapCollection)
                                cardId

                        droppable =
                            case dragId of
                                Just draggingId ->
                                    if (highlights |> Collection.getLocalOrder |> List.elemIndex draggingId) == Just index then
                                        []

                                    else
                                        HtmlA.class "droppable"
                                            :: DragDrop.droppable
                                                (Collection.ReorderHighlights ownerId >> wrapCollection)
                                                index

                                Nothing ->
                                    []

                        hover =
                            if DragDrop.getDropId orderEditor == Just index then
                                [ HtmlA.class "hover" ]

                            else
                                []
                    in
                    ( List.append dragging draggable
                    , List.append droppable hover
                    )

                Nothing ->
                    ( [], [] )

        attrs =
            List.concat
                [ [ HtmlA.class "highlight" ]
                , dragAttrs
                , dropAttrs
                ]

        contents =
            [ viewedCard, Html.div [ HtmlA.class "message" ] messageHtml ]
    in
    ( Card.cssId cardId
    , contents |> Html.li attrs
    )


viewCardTypeWithCards : Maybe (Collection.OnClick Global.Msg) -> CardFilter -> User.Id -> Banner.Id -> CardType.Id -> CardType.WithCards -> FilteredView (Html Global.Msg)
viewCardTypeWithCards onClick filter userId bannerId cardTypeId cardType =
    let
        ( contents, total, shown ) =
            if AssocList.isEmpty cardType.cards then
                let
                    placholderApplied { placeholder } =
                        placeholder bannerId cardTypeId
                in
                ( [ ( CardType.cssId cardTypeId
                    , Html.li [ HtmlA.class "placeholder" ]
                        [ viewPlaceholder
                            (onClick |> Maybe.map placholderApplied)
                            bannerId
                            cardTypeId
                            cardType.cardType
                        ]
                    )
                  ]
                , 1
                , 1
                )

            else
                let
                    cardApplied { card } =
                        card userId bannerId

                    toShow =
                        cardType.cards |> AssocList.filter filter
                in
                ( internalViewCards
                    (onClick |> Maybe.map cardApplied)
                    (\_ -> [])
                    userId
                    bannerId
                    toShow
                , cardType.cards |> AssocList.size
                , toShow |> AssocList.size
                )
    in
    { view = HtmlK.ul [ HtmlA.class "card-set" ] contents
    , total = total
    , shown = shown
    }


viewCardTypesWithCards : Maybe (Collection.OnClick Global.Msg) -> Filter -> User.Id -> Banner.Id -> AssocList.Dict CardType.Id CardType.WithCards -> FilteredView (Html Global.Msg)
viewCardTypesWithCards onClick filter user banner cardTypesWithCards =
    let
        internalView cardTypeId cardType =
            viewCardTypeWithCards onClick filter.card user banner cardTypeId cardType

        viewedCardTypes =
            cardTypesWithCards
                |> AssocList.filter filter.cardType
                |> AssocList.map internalView

        totalCards =
            cardTypesWithCards
                |> AssocList.values
                |> List.map (\t -> max 1 (AssocList.size t.cards))
                |> List.sum

        fold ( id, viewdCardType ) result =
            { cardTypes = ( id, viewdCardType.view ) :: result.cardTypes
            , shown = result.shown + viewdCardType.shown
            }

        { cardTypes, shown } =
            viewedCardTypes
                |> AssocList.toList
                |> List.foldr fold { cardTypes = [], shown = 0 }

        viewListItem ( cardTypeId, cardType ) =
            ( CardType.cssId cardTypeId
            , Html.li [] [ cardType ]
            )

        cards =
            cardTypes |> List.map viewListItem

        viewResult =
            if cards |> List.isEmpty |> not then
                cards |> HtmlK.ol [ HtmlA.class "card-types" ]

            else
                [ Icon.ghost |> Icon.view, Html.span [] [ Html.text "No matching cards." ] ] |> Html.div [ HtmlA.class "empty" ]
    in
    { view = viewResult, total = totalCards, shown = shown }


viewCardTypes : Maybe (Banner.Id -> CardType.Id -> Global.Msg) -> Banner.Id -> AssocList.Dict CardType.Id CardType -> Html Global.Msg
viewCardTypes onClick bannerId =
    let
        viewListItem ( cardTypeId, cardType ) =
            let
                placholderApplied placeholder =
                    placeholder bannerId cardTypeId
            in
            ( CardType.cssId cardTypeId
            , Html.li []
                [ viewPlaceholder
                    (onClick |> Maybe.map placholderApplied)
                    bannerId
                    cardTypeId
                    cardType
                ]
            )
    in
    AssocList.toList >> List.map viewListItem >> HtmlK.ol [ HtmlA.class "card-types" ]
