port module App exposing (..)

import Html exposing (..)
import Html.Attributes exposing (id, class, style, disabled, value, selected)
import Html.Events exposing (onInput)
import Color exposing (rgb)
import Spinner
import Http
import Json.Decode as Decode
import Json.Decode.Pipeline exposing (decode, required)
import RemoteData exposing (WebData)


port formatProducts : String -> Cmd msg


port formattedProducts : (String -> msg) -> Sub msg



-- FLAGS


type alias Flags =
    { nodeEnv : String
    , host : String
    }



-- MODEL


type alias Model =
    { products : WebData (List Product)
    , sortedBy : String
    , flags : Flags
    , spinner : Spinner.Model
    }


type alias ProductId =
    String


type alias Product =
    { id : ProductId
    , size : Int
    , price : Float
    , face : String
    , date : String
    }


initialModel : Flags -> Model
initialModel { nodeEnv, host } =
    Model RemoteData.Loading "" (Flags nodeEnv host) Spinner.init


init : Flags -> ( Model, Cmd Msg )
init flags =
    let
        model =
            initialModel flags
    in
        ( model, fetchProducts model )



-- MESSAGES


type Msg
    = OnFetchProducts (WebData String)
    | ChangeSortBy String
    | DecodeProducts String
    | SpinnerMsg Spinner.Msg



-- COMMANDS


fetchProducts : Model -> Cmd Msg
fetchProducts { flags, sortedBy } =
    Http.getString (productsUrl flags sortedBy)
        |> RemoteData.sendRequest
        |> Cmd.map OnFetchProducts


apiUrl : String -> String -> String
apiUrl nodeEnv host =
    if nodeEnv == "production" then
        "http://" ++ host ++ "/api/"
    else
        "http://localhost:8000/api/"


productsUrl : Flags -> String -> String
productsUrl { nodeEnv, host } sortedBy =
    let
        param =
            if sortedBy == "" then
                ""
            else
                "sort=" ++ sortedBy
    in
        apiUrl nodeEnv host ++ "products?" ++ param


productsDecoder : Decode.Decoder (List Product)
productsDecoder =
    Decode.list productDecoder


productDecoder : Decode.Decoder Product
productDecoder =
    decode Product
        |> required "id" Decode.string
        |> required "size" Decode.int
        |> required "price" Decode.float
        |> required "face" Decode.string
        |> required "date" Decode.string



-- VIEW


view : Model -> Html Msg
view model =
    div [ id "wrapper" ]
        [ header [ id "app-header" ]
            [ h1 [] [ text "Discount ASCII Warehouse" ]
            , p []
                [ text
                    """
                    Here you're sure to find a bargain on some of the finest ascii
                    available to purchase. Be sure to peruse our selection of ascii
                    faces in an exciting range of sizes and prices.
                    """
                ]
            ]
        , main_ []
            [ sortDropdown model
            , maybeList model
            ]
        ]


spinnerConfig : Spinner.Config
spinnerConfig =
    let
        cfg =
            Spinner.defaultConfig
    in
        { cfg
            | scale = 0.3
            , color = (\_ -> rgb 93 207 243)
        }


maybeList : Model -> Html Msg
maybeList { products, spinner } =
    case products of
        RemoteData.Loading ->
            Spinner.view spinnerConfig spinner

        RemoteData.Success productsResp ->
            productList productsResp

        _ ->
            text ""


defaultSortingOptions : List String
defaultSortingOptions =
    [ "price", "size", "id" ]


sortDropdown : Model -> Html Msg
sortDropdown { products } =
    let
        isDisabled =
            if products == RemoteData.Loading then
                True
            else
                False
    in
        select [ onInput ChangeSortBy, disabled isDisabled ]
            (option [ disabled True, selected True ] [ text "Select..." ]
                :: List.map optionView defaultSortingOptions
            )


optionView : String -> Html Msg
optionView optionValue =
    option [ value optionValue ] [ text optionValue ]


productList : List Product -> Html Msg
productList products =
    div [ class "grid" ]
        (List.map productItem products)


productItem : Product -> Html Msg
productItem { size, price, face, date } =
    div [ class "card animated fadeIn" ]
        [ div [ class "product", style [ ( "font-size", (toString size ++ "px") ) ] ]
            [ pre [] [ text face ] ]
        , div [ class "description" ]
            [ span [ class "added" ] [ text ("Added " ++ date) ]
            , span [ class "price" ] [ text ("$" ++ toString price) ]
            ]
        ]



-- UPDATE


decodeProductsJSON : String -> WebData (List Product)
decodeProductsJSON json =
    let
        result =
            Decode.decodeString productsDecoder json
    in
        case result of
            Ok products ->
                RemoteData.Success products

            Err _ ->
                RemoteData.Success []


validateResponse : Model -> WebData String -> ( Model, Cmd Msg )
validateResponse model response =
    case response of
        RemoteData.Success json ->
            ( model, formatProducts json )

        _ ->
            ( model, Cmd.none )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        OnFetchProducts response ->
            validateResponse model response

        DecodeProducts response ->
            ( { model | products = decodeProductsJSON response }, Cmd.none )

        ChangeSortBy optionValue ->
            ( { model
                | sortedBy = optionValue
                , products = RemoteData.Loading
              }
            , fetchProducts model
            )

        SpinnerMsg msg ->
            let
                spinnerModel =
                    Spinner.update msg model.spinner
            in
                ( { model | spinner = spinnerModel }, Cmd.none )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    let
        spinnerSub =
            if model.products == RemoteData.Loading then
                Sub.map SpinnerMsg Spinner.subscription
            else
                Sub.none
    in
        Sub.batch
            [ spinnerSub
            , formattedProducts DecodeProducts
            ]



-- MAIN PROGRAM


main : Program Flags Model Msg
main =
    programWithFlags
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }
