module Util.Result.Pipeline exposing
    ( hardcoded
    , integrate
    )


integrate : (e -> e -> e) -> Result e a -> Result e (a -> b) -> Result e b
integrate combineErrors next previous =
    case previous of
        Ok f ->
            case next of
                Ok v ->
                    v |> f |> Ok

                Err nextErrors ->
                    nextErrors |> Err

        Err previousErrors ->
            case next of
                Ok _ ->
                    previousErrors |> Err

                Err nextErrors ->
                    combineErrors previousErrors nextErrors |> Err


hardcoded : a -> Result e (a -> b) -> Result e b
hardcoded value previous =
    case previous of
        Ok f ->
            value |> f |> Ok

        Err previousErrors ->
            Err previousErrors
