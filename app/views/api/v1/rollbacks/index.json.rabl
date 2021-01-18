object false

child @collection => :rollbacks do
  extends('api/v1/rollbacks/rollback_job')
end

extends 'api/v1/shared/pagination'
