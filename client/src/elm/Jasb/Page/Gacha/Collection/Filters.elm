module Jasb.Page.Gacha.Collection.Filters exposing
    ( defaultFilters
    , filterBy
    , viewFilters
    )

import AssocList
import EverySet exposing (EverySet)
import Html exposing (Html)
import Html.Attributes as HtmlA
import Jasb.Filtering as Filtering
import Jasb.Gacha.Card exposing (Card)
import Jasb.Gacha.CardType.WithCards as CardType
import Jasb.Gacha.Context.Model as Gacha
import Jasb.Gacha.Quality as Quality
import Jasb.Messages as Global
import Jasb.Page.Gacha.Card.Model as Card
import Jasb.Page.Gacha.Collection.Filters.Model exposing (..)
import Jasb.Page.Gacha.Collection.Model exposing (..)
import Material.Chips.Filter as FilterChip
import Util.AssocList as AssocList
import Util.Maybe as Maybe


wrap : Msg -> Global.Msg
wrap =
    Global.CollectionMsg


possibleFilters : Gacha.Context -> Filters
possibleFilters context =
    { ownership = [ Owned, NotOwned, OnlyDuplicates ] |> EverySet.fromList
    , quality =
        NoQualities
            :: (context |> Gacha.qualitiesFromContext |> AssocList.listOf HasQuality)
            |> EverySet.fromList
    , rarity =
        context
            |> Gacha.raritiesFromContext
            |> AssocList.listOf HasRarity
            |> EverySet.fromList
    }


defaultFilters : FilterModel
defaultFilters =
    { ownership = [ NotOwned, OnlyDuplicates ] |> EverySet.fromList
    , quality = Nothing
    , rarity = Nothing
    }


hasNoQuality : Card -> Bool
hasNoQuality { individual } =
    AssocList.isEmpty individual.qualities


hasQuality : Quality.Id -> Card -> Bool
hasQuality id { individual } =
    AssocList.member id individual.qualities


cardQualityCriteria : QualityFilter -> Filtering.Criteria Card
cardQualityCriteria filter =
    case filter of
        NoQualities ->
            Filtering.Include hasNoQuality

        HasQuality id _ ->
            Filtering.Include (hasQuality id)


cardTypeOwnershipCriteria : OwnershipFilter -> Filtering.Criteria CardType.WithCards
cardTypeOwnershipCriteria filter =
    case filter of
        Owned ->
            Filtering.Include (\{ cards } -> cards |> AssocList.isEmpty |> not)

        NotOwned ->
            Filtering.Include (\{ cards } -> cards |> AssocList.isEmpty)

        OnlyDuplicates ->
            Filtering.Exclude (\{ cards } -> AssocList.size cards < 2)


cardTypeQualityCriteria : QualityFilter -> Filtering.Criteria CardType.WithCards
cardTypeQualityCriteria filter =
    case filter of
        NoQualities ->
            Filtering.Include (\{ cards } -> cards |> AssocList.values |> List.any hasNoQuality)

        HasQuality id _ ->
            Filtering.Include (\{ cards } -> cards |> AssocList.values |> List.any (hasQuality id))


cardTypeRarityCriteria : RarityFilter -> Filtering.Criteria CardType.WithCards
cardTypeRarityCriteria filter =
    case filter of
        HasRarity id _ ->
            Filtering.Include (\{ cardType } -> Tuple.first cardType.rarity == id)


filterBy : FilterModel -> Gacha.Context -> Card.Filter
filterBy disabledFilters context =
    let
        all =
            possibleFilters context

        disabledWithDeps =
            if EverySet.member Owned disabledFilters.ownership then
                EverySet.insert OnlyDuplicates disabledFilters.ownership

            else
                disabledFilters.ownership

        ownership =
            EverySet.diff all.ownership disabledWithDeps

        toPredicate set toCriteria =
            set
                |> EverySet.toList
                |> List.map toCriteria
                |> Filtering.combine
                |> Filtering.toPredicate

        cardTypeOwnership =
            toPredicate ownership cardTypeOwnershipCriteria

        cardTypeRarity =
            case disabledFilters.rarity of
                Just exclude ->
                    let
                        rarity =
                            EverySet.diff all.rarity exclude
                    in
                    toPredicate rarity cardTypeRarityCriteria

                Nothing ->
                    \_ -> True

        ( cardQuality, cardTypeQuality ) =
            case disabledFilters.quality of
                Just exclude ->
                    let
                        quality =
                            EverySet.diff all.quality exclude
                    in
                    ( toPredicate quality cardQualityCriteria
                    , toPredicate quality cardTypeQualityCriteria
                    )

                Nothing ->
                    ( \_ -> True, \_ -> True )
    in
    { card = \_ -> cardQuality
    , cardType =
        \_ cardType ->
            cardTypeOwnership cardType
                && cardTypeRarity cardType
                && cardTypeQuality cardType
    }


viewRarityToggle : FilterModel -> Html Global.Msg
viewRarityToggle { rarity } =
    FilterChip.chip "By Rarity..."
        |> FilterChip.button (rarity == Nothing |> ShowRarityFilters |> wrap |> Just)
        |> FilterChip.selected (rarity /= Nothing)
        |> FilterChip.attrs [ HtmlA.title "Show rarity-based filters." ]
        |> FilterChip.view


viewQualityToggle : FilterModel -> Html Global.Msg
viewQualityToggle { quality } =
    FilterChip.chip "By Quality..."
        |> FilterChip.button (quality == Nothing |> ShowQualityFilters |> wrap |> Just)
        |> FilterChip.selected (quality /= Nothing)
        |> FilterChip.attrs [ HtmlA.title "Show quality-based filters." ]
        |> FilterChip.view


viewOwnershipFilter : EverySet OwnershipFilter -> OwnershipFilter -> Html Global.Msg
viewOwnershipFilter ownership filter =
    let
        ( label, description ) =
            case filter of
                Owned ->
                    ( "Owned", "Show cards this user has a copy of." )

                NotOwned ->
                    ( "Not Owned", "Show cards this user doesn't have a copy of." )

                OnlyDuplicates ->
                    ( "Only Duplicates", "Show only cards with mutliple copies." )

        disabled =
            filter == OnlyDuplicates && EverySet.member Owned ownership
    in
    FilterChip.chip label
        |> FilterChip.button (filter |> Ownership |> ToggleFilter |> wrap |> Maybe.whenNot disabled)
        |> FilterChip.selected (ownership |> EverySet.member filter |> not)
        |> FilterChip.attrs [ HtmlA.title description ]
        |> FilterChip.view


viewRarityFilter : EverySet RarityFilter -> RarityFilter -> Html Global.Msg
viewRarityFilter rarity filter =
    let
        ( label, description ) =
            case filter of
                HasRarity _ { name } ->
                    ( name, "Show cards that have the " ++ name ++ " rarity." )
    in
    FilterChip.chip label
        |> FilterChip.button (filter |> Rarity |> ToggleFilter |> wrap |> Just)
        |> FilterChip.selected (rarity |> EverySet.member filter |> not)
        |> FilterChip.attrs [ HtmlA.title description ]
        |> FilterChip.view


viewQualityFilter : EverySet QualityFilter -> QualityFilter -> Html Global.Msg
viewQualityFilter quality filter =
    let
        ( label, description ) =
            case filter of
                HasQuality _ { name } ->
                    ( name, "Show cards that have the " ++ name ++ " quality." )

                NoQualities ->
                    ( "No Qualities", "Show cards that have no special qualities." )
    in
    FilterChip.chip label
        |> FilterChip.button (filter |> Quality |> ToggleFilter |> wrap |> Just)
        |> FilterChip.selected (quality |> EverySet.member filter |> not)
        |> FilterChip.attrs [ HtmlA.title description ]
        |> FilterChip.view


viewFilters : Gacha.Context -> FilterModel -> Int -> Int -> Html Global.Msg
viewFilters context model total shown =
    let
        allFilters =
            possibleFilters context

        rarityLine filters =
            allFilters.rarity |> EverySet.toList |> List.map (viewRarityFilter filters)

        qualityLine filters =
            allFilters.quality |> EverySet.toList |> List.map (viewQualityFilter filters)
    in
    [ List.append
        (allFilters.ownership |> EverySet.toList |> List.map (viewOwnershipFilter model.ownership))
        [ viewRarityToggle model, viewQualityToggle model ]
        |> Just
    , model.rarity |> Maybe.map rarityLine
    , model.quality |> Maybe.map qualityLine
    ]
        |> List.filterMap identity
        |> Filtering.viewFilterSets "Cards" total shown
