module Util.Url exposing (slugify)


slugify : String -> String
slugify =
    let
        isAllowed char =
            char == '-' || Char.isDigit char || Char.isLower char

        removeRepeatedDashes current ( previousWasDash, rest ) =
            if previousWasDash && current == '-' then
                ( True, rest )

            else
                ( current == '-', String.cons current rest )
    in
    String.toLower
        >> String.split " "
        >> String.join "-"
        >> String.filter isAllowed
        >> (String.foldr removeRepeatedDashes ( False, "" ) >> Tuple.second)
        >> String.left 20
