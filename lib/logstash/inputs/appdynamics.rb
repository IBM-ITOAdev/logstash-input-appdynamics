# encoding: utf-8                                                              


require 'logstash/inputs/base'
require 'logstash/namespace'

require 'net/http'
require 'rest-client'
require 'json'
require 'pstore'
require 'java' # for the java data format stuff

class LogStash::Inputs::AppDynamics < LogStash::Inputs::Base
  config_name "appdynamics"
  milestone 1

  default :codec, "plain"
  config :user, :validate => :string, :required => true
  config :address, :validate => :string, :required => true
  config :metricURIs, :validate => :hash, :required => true

  config :start_time, :validate => :string, :default => ""
  config :end_time,   :validate => :string, :default => ""
  config :latency,    :validate => :number, :default => 0 # minutes
  config :aggregation_interval, :validate => :number, :default => 15 # minutes

  config :PStoreFile, :validate => :string, :required => false, :default => ""

  config :sleep_interval, :validate => :number, :default => 10 # seconds
  config :SCAWindowMarker, :validate => :boolean, :default => false

  public
  def register 


  end

  public
  def extractDataForTimestamp(targetTimestamp, interval, metricURIs,curlStringBase, df )
      bufferedEvents = []

      metricURIs.each do | group,uriArray |
        uriArray.each do | uriOriginal |

          @logger.debug("uriOriginal = " + uriOriginal)
          uri = URI.escape(uriOriginal)

          uriTimerange = "&time-range-type=BETWEEN_TIMES&start-time=" + 
                         targetTimestamp.getTime().to_s + 
                         "&end-time=" + (targetTimestamp.getTime() + interval).to_s

          curlString = curlStringBase +  uri + uriTimerange + "&output=JSON'" 

          @logger.debug("curlString = " + curlString)

          response = `#{curlString}` 
          # `curl --user rmckeown@customer1:appdynamics 'http://oc3122150850.ibm.com:8090/controller/rest/applications/Database%20Monitoring/metric-data?metric-path=Databases%7CRESO131%7CKPI%7C*&time-range-type=BEFORE_NOW&duration-in-mins=60&output=JSON'`

#puts("response = " + response)

          begin 
            responseHash = JSON.parse(response)
            @logger.debug("response = " + responseHash.to_s)

            responseHash.each do | e |
              if e['metricName'] == "METRIC DATA NOT FOUND"
              else
                event = LogStash::Util.hash_merge(LogStash::Event.new,e)
                event['group'] = group
                decorate(event)

                # unpack the fields and create names
                metricNameSplit = event['metricName'].split("|")
                (0..metricNameSplit.length-1).each do |i|
                  event['metricName' + i.to_s ] = metricNameSplit[i]
                end 
                metricPathSplit = event['metricPath'].split("|")
                (0..metricPathSplit.length-1).each do |i|
                  event['metricPath' + i.to_s ] = metricPathSplit[i]
                end 

                # extract key values .. bring them up from nested values to make them top-level attributes
                event['timestamp'] = df.format(event['metricValues'][0]['startTimeInMillis'])
                event['count']     = event['metricValues'][0]['count']
                event['value']     = event['metricValues'][0]['value']

                # last field is PI metric (usually)
                event['metric']   = metricPathSplit[metricPathSplit.length-1]
                # and all but the last field is generally the PI resource
                event['resource'] = metricPathSplit.slice(0,metricPathSplit.length-1).join("|")

                bufferedEvents.push(event)
              end # if
            end
          rescue Exception => e
            @logger.error("Ignoring response: " + response, :exception => e)
          end
        end
 
        # should sort events here, by timestamp
      end

      bufferedEvents
  end

  public
  def run(queue)

    store = "" # placeholder

    timeIncrement = @aggregation_interval * 60000 # convert supplied minutes to milliseconds
    curlStringBase = "curl --user " + user + " 'http://" + address + "/controller/rest/" 

#    df = java.text.SimpleDateFormat.new("yyyyMMdd HHmm") # format corresponds to PI mediation format
    df = java.text.SimpleDateFormat.new("yyyy-MM-dd'T'HH:mm:ssZ") # format corresponds to PI mediation format

    endTime   = df.parse("2100-01-01T00:00:00-0000") # long time in the future. Only used if user didn't specify end time so we can run 'forever'

    latencySec = latency * 60 

    # Establish start time, using configured @start_time if present, and defaulting to current time, if it is not
    if @start_time != "" then
        startTime = df.parse(@start_time)
        puts("Setting start time from .conf as " + startTime.to_s )
    else
        startTime = java.util.Date.new
        puts("Setting start time as current time " + startTime.to_s )
    end    

puts("Start time = " + startTime.to_s)

    # startTime can be overridden by a configured PStore file

    # Initialize the PStore if necessary
    if !@PStoreFile.eql?("")
      # Actual PStoreFile defined
      if !File.exist?(@PStoreFile)
        # but one doesn't exit, prepare the store where we'll track most recent timestamp
        store = PStore.new(@PStoreFile)
      else
        # store file does exist, so read start time from that, and if we can't read it, use the prepared startTime from above
        startTime = store.transaction { store.fetch(:targetTime, startTime ) }  
      end
    end

    if @end_time != "" then
       endTime = df.parse(@end_time)
    end



    # start from the specified startTime
    targetTime = startTime

    begin

      if ( targetTime < (Time.now() - latencySec) ) 

        bufferedEvents = extractDataForTimestamp(targetTime, timeIncrement, @metricURIs, curlStringBase, df)

        # output all events
        bufferedEvents.each do | e |
          queue << e
        end

        # if we are configured to output the window marker punctuations, do it now
        # but only if there are some metric values
        if (@SCAWindowMarker and (bufferedEvents.length > 0)) 
         event = LogStash::Event.new("SCAWindowMarker" => true)
          decorate(event)
          queue << event
        end
        bufferedEvents.clear

        # move to next time interval
        targetTime.setTime(targetTime.getTime() + timeIncrement)
        if !@PStoreFile.eql?("")
puts("Writing targetTime of " + targetTime.to_s + " to store ")
          store.transaction do store[:targetTime] = targetTime end
        end

      else
        # wait a bit before trying again
        sleep(@sleep_interval)
      end

    end until(targetTime.getTime() >= endTime.getTime())

    finished
  end

  public
  def teardown
  end

end # class LogStash::Inputs::AppDynamics
