if @actor.tombstoned?
  json.partial! 'federails/server/actors/tombstone', actor: @actor
else
  json.partial! 'federails/server/actors/actor', actor: @actor
end
