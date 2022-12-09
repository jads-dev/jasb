module JoeBets.Page.Leaderboard.Route exposing
    ( Board(..)
    , boardFromString
    , boardToString
    )


type Board
    = NetWorth
    | Debt


boardToString : Board -> String
boardToString board =
    case board of
        NetWorth ->
            "net-worth"

        Debt ->
            "debt"


boardFromString : String -> Maybe Board
boardFromString board =
    case board of
        "net-worth" ->
            Just NetWorth

        "debt" ->
            Just Debt

        _ ->
            Nothing
