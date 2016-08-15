module Dispatch
  exposing
    ( Msg
    , forward
    , listeners
    , group
    )

{-| Utility module for dispatching multiple events from a single `Html.Event`

@docs Msg
@docs forward
@docs listeners
-}

import Material.Helpers as Helpers
import Json.Decode as Json
import Html.Events
import Html
import Dict exposing (Dict)


{-| Message type
-}
type Msg m
  = Forward (List m)


{-| Maps messages to commands
-}
forward : Msg m -> Cmd m
forward (Forward messages) =
  List.map Helpers.cmd messages |> Cmd.batch


{-| Applies given decoders to the same initial value
   and return the applied results as a list
-}
applyMultipleDecoders : List (Json.Decoder m) -> Json.Decoder (List m)
applyMultipleDecoders decoders =
  let
    processDecoder initial decoder =
      case (Json.decodeValue decoder initial) of
        Ok smt ->
          Just smt

        Err _ ->
          Nothing
  in
    Json.customDecoder Json.value
      (\initial ->
        List.map (processDecoder initial) decoders
          |> List.filterMap identity
          |> Result.Ok
      )


{-|
-}
forwardDecoder : List (Json.Decoder a) -> Json.Decoder (Msg a)
forwardDecoder =
  applyMultipleDecoders >> (Json.map Forward)


{-| Run multiple decoders on a single Html Event
-}
onEvt :
  (Msg msg -> msg)
  -> String
  -> List (Json.Decoder msg)
  -> Maybe (Html.Attribute msg)
onEvt lift event decoders =
  case decoders of
    [] ->
      Nothing

    [ x ] ->
      Html.Events.on event x
        |> Just

    _ ->
      forwardDecoder decoders
        |> Json.map lift
        |> Html.Events.on event
        |> Just


{-| Updates value by given function if found, inserts otherwise
-}
upsert : comparable -> m -> (Maybe m -> Maybe m) -> Dict comparable m -> Dict comparable m
upsert key value func dict =
  if Dict.member key dict then
    Dict.update key func dict
  else
    Dict.insert key value dict

{-|
-}
group : List ( comparable, a ) -> List ( comparable, List a )
group items =
  items
    |> List.foldr
       (\( k, v ) accum ->
         upsert k [ v ] (Maybe.map (\a -> v :: a)) accum
       )
       Dict.empty
    |> Dict.toList


{-| Combines decoders for events and returns event listeners
-}
listeners :
  (Msg a -> a)
  -> List ( String, List (Json.Decoder a) )
  -> List (Html.Attribute a)
listeners lift items =
  items
    |> List.map (\( event, decoders ) -> onEvt lift event decoders)
    |> List.filterMap identity
