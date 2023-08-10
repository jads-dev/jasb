module ReviewConfig exposing (config)


import Review.Rule exposing (Rule)
import NoDeprecated
import NoExposingEverything
import NoImportingEverything
import NoMissingTypeAnnotation
import NoMissingTypeExpose
import NoPrematureLetComputation
import NoMissingSubscriptionsCall
import NoRecursiveUpdate
import NoUselessSubscriptions
import NoRedundantConcat
import NoRedundantCons
import NoUnused.Dependencies
import NoUnused.Variables
import NoAlways
import NoBooleanCase
import NoDebug.Log
import NoDebug.TodoOrToString
import NoDuplicatePorts
import NoUnsafePorts
import NoUnusedPorts
import NoInconsistentAliases
import NoModuleOnExposedNames
import NoUnoptimizedRecursion

config : List Rule
config =
    [ NoExposingEverything.rule
    , NoDeprecated.rule NoDeprecated.defaults
    , NoMissingTypeAnnotation.rule
    , NoPrematureLetComputation.rule
    , NoMissingSubscriptionsCall.rule
    , NoRecursiveUpdate.rule
    , NoUselessSubscriptions.rule
    , NoRedundantConcat.rule
    , NoRedundantCons.rule
    , NoUnused.Dependencies.rule
    , NoUnused.Variables.rule
    , NoAlways.rule
    , NoBooleanCase.rule
    , NoDebug.Log.rule
    , NoDebug.TodoOrToString.rule
    , NoDuplicatePorts.rule
    , NoUnsafePorts.rule NoUnsafePorts.any

    --, NoUnusedPorts.rule -- False positive.
    , NoInconsistentAliases.config
        [ ( "Html.Attributes", "HtmlA" )
        , ( "Html.Events", "HtmlE" )
        , ( "Html.Keyed", "HtmlK" )
        , ( "Html.Lazy", "HtmlL" )
        , ( "Json.Decode", "JsonD" )
        , ( "Json.Encode", "JsonE" )
        , ( "Util.AssocList", "AssocList" )
        , ( "Util.EverySet", "EverySet" )
        , ( "Util.Html", "Html" )
        , ( "Util.Html.Events", "HtmlE" )
        , ( "Util.Http.StatusCodes", "Http" )
        , ( "Util.Json.Decode", "JsonD" )
        , ( "Util.Json.Encode", "JsonE" )
        , ( "Util.Json.Encode.Pipeline", "JsonE" )
        , ( "Util.Result", "Result" )
        , ( "Util.Result.Pipeline", "Result" )
        , ( "Util.Maybe", "Maybe" )
        , ( "Util.List", "List" )
        , ( "Util.Order", "Order" )
        , ( "Util.String", "String" )
        , ( "Util.Url", "Url" )
        , ( "Browser.Events", "Browser" )
        , ( "Browser.Navigation", "Browser" )
        , ( "JoeBets.Api.Action", "Api" )
        , ( "JoeBets.Api.Data", "Api" )
        , ( "JoeBets.Api.IdData", "Api" )
        , ( "JoeBets.Api.Path", "Api" )
        , ( "List.Extra", "List" )
        ]
        |> NoInconsistentAliases.noMissingAliases
        |> NoInconsistentAliases.rule
    , NoModuleOnExposedNames.rule
    , NoUnoptimizedRecursion.rule (NoUnoptimizedRecursion.optOutWithComment "Known Inefficient Recursion")
    ]
