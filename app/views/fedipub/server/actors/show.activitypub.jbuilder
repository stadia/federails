if @actor.tombstoned?
  json.partial! 'fedipub/server/actors/tombstone', actor: @actor
else
  json.partial! 'fedipub/server/actors/actor', actor: @actor
end
