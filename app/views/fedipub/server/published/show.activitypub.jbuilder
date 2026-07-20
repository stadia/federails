if @publishable.fedipub_tombstoned?
  json.partial! 'fedipub/server/published/tombstone', publishable: @publishable
else
  json.partial! 'fedipub/server/published/publishable', publishable: @publishable
end
