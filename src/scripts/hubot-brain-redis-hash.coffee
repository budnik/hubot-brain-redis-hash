# Description:
#   None
#
# Dependencies:
#   "redis": "0.7.2"
#
# Configuration:
#   REDISTOGO_URL
#
# Commands:
#   None
#
# Author:
#   Gavin Mogan <gavin@gavinmogan.com>

'use strict'

Url   = require "url"
Redis = require "redis"

# sets up hooks to persist the brain into redis.
module.exports = (robot) ->
  robot.brain.redis_hash = {}
  client = robot.brain.redis_hash.client = module.exports.createClient()

  oldkeys = {}
  client.on "error", (err) ->
    robot.logger.error err

  client.on "connect", ->
    robot.logger.debug "Successfully connected to Redis"

    client.hgetall "hubot:brain", (err, reply) ->
      if err
        throw err
      else if reply
        robot.logger.info "Brain data retrieved from redis-brain storage"
        results = {}
        oldkeys = {}
        for key in Object.keys(reply)
          results[key] = JSON.parse(reply[key].toString())
          oldkeys[key] = 1
        robot.brain.mergeData results
      else
        robot.logger.info "Initializing new redis-brain storage"
        robot.brain.mergeData {}

      robot.logger.info "Enabling brain auto-saving"
      if robot.brain.setAutoSave?
        robot.brain.setAutoSave true

  # Prevent autosaves until connect has occured
  robot.logger.info "Disabling brain auto-saving"
  if robot.brain.setAutoSave?
    robot.brain.setAutoSave false

  robot.brain.on 'save', (data = {}) ->
    robot.logger.debug "Saving brain data"
    multi = do client.multi
    keys = Object.keys data
    jsonified = {}
    for key in keys
      jsonified[key] = JSON.stringify data[key]
    for key in oldkeys
      if !jsonified[key]
        multi.hdel "hubot:brain", key

    oldkeys = {}
    for key in keys
      if jsonified[key]?
        oldkeys[key] = 1
        multi.hset "hubot:brain", key, jsonified[key]

    multi.exec (err,replies) ->
      robot.brain.emit 'done:save'
      @

  robot.brain.on 'close', ->
    client.quit()

  @

module.exports.createClient = () ->
  info = JSON.parse(process.env.VCAP_SERVICES)['rediscloud'][0].credentials;
  client = Redis.createClient(info.port, info.hostname, {auth_pass: info.password})

  return client
