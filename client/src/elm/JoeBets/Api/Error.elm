module JoeBets.Api.Error exposing
    ( Bug(..)
    , Error(..)
    , Mistake(..)
    , Problem(..)
    , errorToString
    , expectJsonOrError
    , viewError
    )

import Dict
import Html exposing (Html)
import Http
import JoeBets.Error as Error
import Json.Decode as JsonD
import Util.Http.StatusCodes as Http
import Util.Maybe as Maybe


type Bug
    = BadUrl { url : String }
    | BadStatus { url : String, method : String, status : Int, message : Maybe String }
    | BadResponse { url : String, method : String, decodeError : JsonD.Error }
    | InvalidMethod { url : String, method : String }


type Problem
    = Timeout
    | NetworkError
    | ServerDown


type Mistake
    = Unauthorized
    | Forbidden
    | NotFound { url : String }
    | Conflict { url : String }


type Error
    = Application Bug
    | Transient Problem
    | User Mistake


expectJsonOrError : String -> (Result Error value -> msg) -> JsonD.Decoder value -> Http.Expect msg
expectJsonOrError method wrap decoder =
    let
        handle response =
            case response of
                Http.BadUrl_ url ->
                    BadUrl { url = url } |> Application |> Err

                Http.Timeout_ ->
                    Timeout |> Transient |> Err

                Http.NetworkError_ ->
                    NetworkError |> Transient |> Err

                Http.BadStatus_ { url, statusCode, headers } body ->
                    if statusCode == Http.unauthorized then
                        Unauthorized |> User |> Err

                    else if statusCode == Http.forbidden then
                        Forbidden |> User |> Err

                    else if statusCode == Http.notFound then
                        NotFound { url = url } |> User |> Err

                    else if statusCode == Http.methodNotAllowed then
                        InvalidMethod { url = url, method = method }
                            |> Application
                            |> Err

                    else if statusCode == Http.conflict then
                        Conflict { url = url } |> User |> Err

                    else if statusCode == Http.badGateway then
                        ServerDown |> Transient |> Err

                    else if statusCode == Http.serviceUnavailable then
                        ServerDown |> Transient |> Err

                    else if statusCode == Http.gatewayTimeout then
                        ServerDown |> Transient |> Err

                    else if statusCode == Http.networkAuthenticationRequired then
                        NetworkError |> Transient |> Err

                    else
                        let
                            isTextMessage =
                                headers
                                    |> Dict.get "content-type"
                                    |> Maybe.map (String.startsWith "text/plain")
                                    |> Maybe.withDefault False

                            message =
                                body |> Maybe.when isTextMessage
                        in
                        { url = url
                        , method = method
                        , status = statusCode
                        , message = message
                        }
                            |> BadStatus
                            |> Application
                            |> Err

                Http.GoodStatus_ { url } body ->
                    case JsonD.decodeString decoder body of
                        Ok value ->
                            Ok value

                        Err error ->
                            { url = url
                            , method = method
                            , decodeError = error
                            }
                                |> BadResponse
                                |> Application
                                |> Err
    in
    Http.expectStringResponse wrap handle


toDetails : Error -> Error.Details
toDetails error =
    case error of
        Application bug ->
            let
                ( message, detail ) =
                    case bug of
                        BadUrl { url } ->
                            ( "Could not complete your action."
                            , "Invalid URL requested: “" ++ url ++ "”."
                            )

                        InvalidMethod { url, method } ->
                            ( "Could not complete your action."
                            , "Invalid method “" ++ method ++ "” used on “" ++ url ++ "”."
                            )

                        BadStatus { url, method, status } ->
                            ( "Could not complete your action."
                            , "Bad status from server: “" ++ String.fromInt status ++ "” from “" ++ method ++ "” on ““" ++ url ++ "”."
                            )

                        BadResponse { url, method, decodeError } ->
                            ( "There was a problem processing the response of your action."
                            , "Unexpected response: " ++ JsonD.errorToString decodeError ++ " from “" ++ method ++ "” on “" ++ url ++ "”."
                            )
            in
            Error.Details (Error.ApplicationBug { developerDetail = detail }) message

        Transient problem ->
            let
                message =
                    case problem of
                        Timeout ->
                            "We waited and didn't get a response, this likely means there is a network error between you and the website."

                        NetworkError ->
                            "Network error trying to connect, please check your internet connection is working."

                        ServerDown ->
                            "The server is temporarily down, probably to update, please try again in a little while."
            in
            Error.Details Error.TransientProblem message

        User mistake ->
            let
                message =
                    case mistake of
                        Unauthorized ->
                            "Your action was rejected as you are not logged in."

                        Forbidden ->
                            "Your action was rejected as you are not allowed to do this."

                        NotFound _ ->
                            "Your action was rejected as the given resource doesn't exist."

                        Conflict _ ->
                            "Your action was rejected as someone else has edited the item and your edit conflicts."
            in
            Error.Details Error.UserMistake message


viewError : Error -> Html msg
viewError =
    toDetails >> Error.view


errorToString : Error -> String
errorToString =
    toDetails >> Error.toString
