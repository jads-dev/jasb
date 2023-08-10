module JoeBets.Gacha.Banner exposing
    ( Banner
    , Banners
    , EditableBanner
    , EditableBanners
    , Id
    , WithId
    , bannersDecoder
    , class
    , cssId
    , decoder
    , editableBannersDecoder
    , editableDecoder
    , encodeId
    , idDecoder
    , idFromString
    , idParser
    , idToString
    , withIdDecoder
    )

import AssocList
import Color exposing (Color)
import JoeBets.Editing.Slug as Slug exposing (Slug)
import Json.Decode as JsonD
import Json.Decode.Pipeline as JsonD
import Json.Encode as JsonE
import Time.DateTime as DateTime exposing (DateTime)
import Url.Parser as Url
import Util.Json.Decode as JsonD


type Id
    = Id String


idToString : Id -> String
idToString (Id string) =
    string


idParser : Url.Parser (Id -> a) a
idParser =
    Url.custom "BANNER ID" (Id >> Just)


idDecoder : JsonD.Decoder Id
idDecoder =
    JsonD.string |> JsonD.map Id


idFromString : String -> Id
idFromString =
    Id


encodeId : Id -> JsonE.Value
encodeId =
    idToString >> JsonE.string


cssId : Id -> String
cssId id =
    "banner-" ++ idToString id


class : Id -> String
class id =
    "banner-" ++ idToString id


type alias Colors =
    { foreground : Color
    , background : Color
    }


colorsDecoder : JsonD.Decoder Colors
colorsDecoder =
    JsonD.succeed Colors
        |> JsonD.required "foreground" Color.decoder
        |> JsonD.required "background" Color.decoder


type alias Banner =
    { name : String
    , description : String
    , cover : String
    , active : Bool
    , type_ : String
    , colors : Colors
    }


decoder : JsonD.Decoder Banner
decoder =
    JsonD.succeed Banner
        |> JsonD.required "name" JsonD.string
        |> JsonD.required "description" JsonD.string
        |> JsonD.required "cover" JsonD.string
        |> JsonD.optional "active" JsonD.bool True
        |> JsonD.required "type" JsonD.string
        |> JsonD.required "colors" colorsDecoder


type alias WithId =
    ( Id, Banner )


withIdDecoder : JsonD.Decoder WithId
withIdDecoder =
    JsonD.map2 Tuple.pair
        (JsonD.index 0 idDecoder)
        (JsonD.index 1 decoder)


type alias Banners =
    AssocList.Dict Id Banner


bannersDecoder : JsonD.Decoder Banners
bannersDecoder =
    JsonD.assocListFromTupleList idDecoder decoder


type alias EditableBanner =
    { id : Slug Id
    , name : String
    , description : String
    , cover : String
    , active : Bool
    , type_ : String
    , colors : Colors

    -- Metadata
    , version : Int
    , created : DateTime
    , modified : DateTime
    }


editableDecoder : JsonD.Decoder ( Id, EditableBanner )
editableDecoder =
    let
        fromId id =
            JsonD.succeed EditableBanner
                |> JsonD.hardcoded (Slug.Locked id)
                |> JsonD.required "name" JsonD.string
                |> JsonD.required "description" JsonD.string
                |> JsonD.required "cover" JsonD.string
                |> JsonD.required "active" JsonD.bool
                |> JsonD.required "type" JsonD.string
                |> JsonD.required "colors" colorsDecoder
                |> JsonD.required "version" JsonD.int
                |> JsonD.required "created" DateTime.decoder
                |> JsonD.required "modified" DateTime.decoder
                |> JsonD.map (\b -> ( id, b ))
    in
    JsonD.index 0 idDecoder
        |> JsonD.andThen (\id -> JsonD.index 1 (fromId id))


type alias EditableBanners =
    { banners : AssocList.Dict Id EditableBanner
    , order : List Id
    }


editableBannersDecoder : JsonD.Decoder EditableBanners
editableBannersDecoder =
    let
        fromAssocList banners =
            EditableBanners banners (banners |> AssocList.keys)
    in
    JsonD.list editableDecoder
        |> JsonD.map (List.reverse >> AssocList.fromList >> fromAssocList)
