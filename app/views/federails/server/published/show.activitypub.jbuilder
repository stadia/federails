if @publishable.federails_tombstoned?
  json.partial! 'federails/server/published/tombstone', publishable: @publishable
else
  json.partial! 'federails/server/published/publishable', publishable: @publishable
end
