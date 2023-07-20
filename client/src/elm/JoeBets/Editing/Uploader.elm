module JoeBets.Editing.Uploader exposing
    ( Model
    , Msg(..)
    , State
    , Uploader
    , fromUrl
    , init
    , setUrl
    , toUrl
    , update
    , view
    )

import File exposing (File)
import File.Select as Select
import FontAwesome as Icon
import FontAwesome.Attributes as Icon
import FontAwesome.Solid as Icon
import Html exposing (Html)
import Html.Attributes as HtmlA
import Http
import JoeBets.Api as Api
import Json.Decode as JsonD
import Json.Decode.Pipeline as JsonD
import Material.Attributes as Material
import Material.IconButton as IconButton
import Material.TextField as TextField
import Util.RemoteData as RemoteData


type alias Parent a =
    { a
        | origin : String
    }


type Msg
    = ChangeUrl String
    | RequestFile
    | Upload File
    | ShowError Http.Error


type State
    = Ready
    | Busy
    | Error Http.Error


type alias Model =
    { label : String
    , types : List String
    }


type alias Uploader =
    { url : String
    , state : State
    }


type alias UploadedResponse =
    { url : String }


decoder : JsonD.Decoder UploadedResponse
decoder =
    JsonD.succeed UploadedResponse
        |> JsonD.required "url" JsonD.string


init : Uploader
init =
    { url = ""
    , state = Ready
    }


fromUrl : String -> Uploader
fromUrl url =
    { url = url
    , state = Ready
    }


toUrl : Uploader -> String
toUrl =
    .url


setUrl : String -> Uploader -> Uploader
setUrl url uploader =
    { uploader | url = url }


update : (Msg -> msg) -> Msg -> Parent a -> Model -> Uploader -> ( Uploader, Cmd msg )
update wrap msg { origin } { types } uploader =
    case msg of
        ChangeUrl newUrl ->
            ( { uploader | url = newUrl }, Cmd.none )

        RequestFile ->
            ( uploader, Select.file types (Upload >> wrap) )

        Upload file ->
            let
                handleResponse result =
                    case result of
                        Ok { url } ->
                            ChangeUrl url

                        Err error ->
                            ShowError error
            in
            ( uploader
            , Api.post origin
                { path = Api.Upload
                , body = [ file |> Http.filePart "file" ] |> Http.multipartBody
                , expect = Http.expectJson (handleResponse >> wrap) decoder
                }
            )

        ShowError error ->
            ( { uploader | state = Error error }, Cmd.none )


view : (Msg -> msg) -> Model -> Uploader -> Html msg
view wrap { label } { url, state } =
    let
        ifNotBusy value =
            case state of
                Busy ->
                    Nothing

                _ ->
                    Just value

        uploadIcon =
            Icon.upload
                |> ifNotBusy
                |> Maybe.withDefault (Icon.spinner |> Icon.styled [ Icon.spinPulse ])
                |> Icon.view

        error =
            case state of
                Error e ->
                    [ Html.p [ HtmlA.class "error" ] [ e |> RemoteData.errorToString |> Html.text ] ]

                _ ->
                    []

        core =
            Html.div []
                [ TextField.viewWithAttrs label
                    TextField.Url
                    url
                    (ChangeUrl >> wrap |> ifNotBusy)
                    [ Material.outlined ]
                , IconButton.view uploadIcon
                    ("Upload " ++ label)
                    (RequestFile |> wrap |> ifNotBusy)
                ]
    in
    [ [ core ], error ] |> List.concat |> Html.div [ HtmlA.class "uploader" ]
