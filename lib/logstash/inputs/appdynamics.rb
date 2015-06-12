# encoding: utf-8                                                              
#

require 'logstash/inputs/base'
require 'logstash/namespace'

require 'net/http'
require 'rest-client'
require 'json'
require 'java' # for the java data format stuff

class LogStash::Inputs::AppDynamics < LogStash::Inputs::Base
  config_name "appdynamics"

  default :codec, "plain"
  config :user, :validate => :string, :required => true
  config :address, :validate => :string, :required => true
  config :metricURIs, :validate => :hash, :required => true

  config :start_time, :validate => :string, :default => ""
  config :end_time,   :validate => :string, :default => ""
  config :latency,    :validate => :number, :default => 0 # minutes
  config :aggregation_interval, :validate => :number, :default => 15 # minutes

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

#puts("uriOriginal = " + uriOriginal)
          uri = URI.escape(uriOriginal)

          uriTimerange = "&time-range-type=BETWEEN_TIMES&start-time=" + 
                         targetTimestamp.getTime().to_s + 
                         "&end-time=" + (targetTimestamp.getTime() + interval).to_s

          curlString = curlStringBase +  uri + uriTimerange + "&output=JSON'" 

#puts("curlString = " + curlString)

          response = `#{curlString}` 
          # `curl --user rmckeown@customer1:appdynamics 'http://oc3122150850.ibm.com:8090/controller/rest/applications/Database%20Monitoring/metric-data?metric-path=Databases%7CRESO131%7CKPI%7C*&time-range-type=BEFORE_NOW&duration-in-mins=60&output=JSON'`

          responseHash = JSON.parse(response)
#puts("responseHash=" + responseHash.to_s)

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

              bufferedEvents.push(event)
            end # if
          end
        end
 
        # should sort events here, by timestamp
      end

      bufferedEvents
  end

  public
  def run(queue)

    timeIncrement = @aggregation_interval * 60000 # convert supplied minutes to milliseconds
    curlStringBase = "curl --user " + user + " 'http://" + address + "/controller/rest/" 

#    df = java.text.SimpleDateFormat.new("yyyyMMdd HHmm") # format corresponds to PI mediation format
    df = java.text.SimpleDateFormat.new("yyyy-MM-dd'T'HH:mm:ssZ") # format corresponds to PI mediation format

    endTime   = df.parse("2100-01-01T00:00:00-0000") # long time in the future. Only used if user didn't specify end time so we can run 'forever'

    if @start_time != "" then
       startTime = df.parse(@start_time)
    else
#       # get start time, snapping to the nearest boundary e.g. 00:00 00:05, 00:15 .. depending on the increment
#       startTime = Calendar.getInstance().getTime()
    end
    if @end_time != "" then
       endTime = df.parse(@end_time)
    end

    latencySec = latency * 60 

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