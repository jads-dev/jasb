module Color exposing
    ( Color
    , black
    , decoder
    , encode
    , fromHexString
    , picker
    , toHexString
    , toHexStringWithoutAlpha
    , white
    )

import Html exposing (Html)
import Json.Decode as JsonD
import Json.Encode as JsonE
import Material.TextField as TextField
import Parser exposing ((|.), (|=), Parser)
import Set exposing (Set)


type Color
    = Color String


validChars : Set Char
validChars =
    "0123456789abcdefABCDEF" |> String.toList |> Set.fromList


validCharString : Parser String
validCharString =
    Parser.chompWhile (\c -> Set.member c validChars)
        |> Parser.getChompedString


parser : Parser Color
parser =
    let
        fromChars r1 r2 g1 g2 b1 b2 a1 a2 =
            [ r1, r2, g1, g2, b1, b2, a1, a2 ]
                |> String.fromList
                |> Color
                |> Parser.succeed

        standardise string =
            case string |> String.toList of
                [ _, _, _, _, _, _, _, _ ] ->
                    string |> Color |> Parser.succeed

                [ r1, r2, g1, g2, b1, b2 ] ->
                    fromChars r1 r2 g1 g2 b1 b2 'f' 'f'

                [ r, g, b, a ] ->
                    fromChars r r g g b b a a

                [ r, g, b ] ->
                    fromChars r r g g b b 'f' 'f'

                _ ->
                    Parser.problem "Not a valid hex colour."
    in
    Parser.succeed String.toLower
        |. Parser.symbol "#"
        |= validCharString
        |> Parser.andThen standardise


fromHexString : String -> Maybe Color
fromHexString string =
    string |> Parser.run parser |> Result.toMaybe


toHexString : Color -> String
toHexString (Color string) =
    "#" ++ string


toHexStringWithoutAlpha : Color -> String
toHexStringWithoutAlpha =
    toHexString >> String.dropRight 2


decoder : JsonD.Decoder Color
decoder =
    let
        fromJsonString string =
            case string |> Parser.run parser of
                Ok color ->
                    JsonD.succeed color

                Err error ->
                    error |> Parser.deadEndsToString |> JsonD.fail
    in
    JsonD.string |> JsonD.andThen fromJsonString


encode : Color -> JsonE.Value
encode =
    toHexString >> JsonE.string


white : Color
white =
    Color "ffffffff"


black : Color
black =
    Color "000000ff"


picker : String -> Maybe (String -> msg) -> String -> Html msg
picker title onChange value =
    TextField.outlined title onChange value
        |> TextField.color
        |> TextField.view
