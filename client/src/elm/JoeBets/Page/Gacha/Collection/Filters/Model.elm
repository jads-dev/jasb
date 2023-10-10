module JoeBets.Page.Gacha.Collection.Filters.Model exposing
    ( Filter(..)
    , FilterModel
    , Filters
    , OwnershipFilter(..)
    , QualityFilter(..)
    , RarityFilter(..)
    )

import EverySet exposing (EverySet)
import JoeBets.Gacha.Quality as Quality exposing (Quality)
import JoeBets.Gacha.Rarity as Rarity exposing (Rarity)


type OwnershipFilter
    = Owned
    | NotOwned
    | OnlyDuplicates


type QualityFilter
    = HasQuality Quality.Id Quality
    | NoQualities


type RarityFilter
    = HasRarity Rarity.Id Rarity


type Filter
    = Ownership OwnershipFilter
    | Quality QualityFilter
    | Rarity RarityFilter


{-| We keep filters that are _not_ enabled as we enable them by default, and that
way loading is easier.
-}
type alias Filters =
    { ownership : EverySet OwnershipFilter
    , quality : EverySet QualityFilter
    , rarity : EverySet RarityFilter
    }


type alias FilterModel =
    { ownership : EverySet OwnershipFilter
    , quality : Maybe (EverySet QualityFilter)
    , rarity : Maybe (EverySet RarityFilter)
    }
