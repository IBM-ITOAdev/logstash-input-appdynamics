<html>
<head>
<meta charset="UTF-8">
<title>Logstash for SCAPI - input appdynamics</title>
<link rel="stylesheet" href="http://logstash.net/style.css">
</head>
<body>
<div class="container">
<div class="header">

<!--main content goes here, yo!-->
<div class="content_wrapper">
<h2>appdynamics</h2>
<h3> Synopsis </h3>
Connects to AppDynamics, and, on a configured schedule, extracts metrics from the REST i/f based upon the supplied set of URLs
<pre><code>onput{
appdynamics {
  <a href="#user">user</a> => ... # string (required)
  <a href="#address">address</a> => ... # string (required)
  <a href="#metricURIs">metricURIs</a> => ... # hash (required)
  <a href="start_time">start_time</a> => ... # string (optional), default: current time is used
  <a href="end_time">start_time</a> => ... # string (optional), default: none
  <a href="latency">latency</a> => ... # number (optional), default: 0 minutes
  <a href="aggregation_interval">aggregation_interval</a> => ... # number (optional), default: 15 minutes
  <a href="SCAWindowMarker">SCAWindowMarker</a> => ... # boolean (optional), default: false
  }
}
</code></pre>
<h3> Details </h3>
Connects to AppDynamics, on a schedule, will extract data (using Curl commands constructued from the various metricURIs and user and address info.  Some basic processing of the returned JSON data will be carried out, mapping to named fields, and having some, ie timestamp, metric and resource of particular use with IBM Predictive Insights
<h4>
<a name="user">
user
</a>
</h4>
<ul>
<li> Value type is <a href="http://logstash.net/docs/1.4.2/configuration#string">String</a> </li>
<li> There is no default value for this setting </li>
</ul>
<p>Specify the AppDynamics user name - used when connecting to AppDynamics</p>
<h4>
<a name="address">
address
</a>
</h4>
<ul>
<li> Value type is <a href="http://logstash.net/docs/1.4.2/configuration#string">String</a> </li>
<li> There is no default value for this setting</li>
</ul>
<p>
The address (ip:port, domain name etc) of the AppDynamic server
</p>
<h4>
<a name="metricURIs">
path
</a>
</h4>
<ul>
<li> Value type is <a href="http://logstash.net/docs/1.4.2/configuration#hash">hash</a> </li>
<li> Default value is "" </li>
</ul>
<p>
These form the basis for the REST URLs which will be run by the plugin. They are arranged as groups of URLS. The plugin will iterate through each group, and execute a REST command for each URL within that group. In addition to the data retrieved from AppDynamics, each event will have a 'group' attribute assigned too. This can be useful in separating data downstream in logstash to different outputs based upon groups.
<p>Use
<code>https://docs.appdynamics.com/display/PRO14S/Use+the+AppDynamics+REST+API as guidance</code>
<p>Example entries</p>
<pre><code>
 metricURIs => {
    "GroupTest" => ["applications/PNSE/metric-data?metric-path=Overall Application Performance|D84-Portal|*"]
    "GroupBusinessTransactions" => [
             "applications/CN/metric-data?metric-path=Business Transaction Performance|Business Transactions|Portal|Entry|Individual Nodes|*|*",
             "applications/CN/metric-data?metric-path=Business Transaction Performance|Business Transactions|Portal|Exit|Individual Nodes|*|*" ]
</code></pre>
</p>
<h4>
<a name="start_time">
start_time (optional setting)
</a>
</h4>
<ul>
<li> Value type is <a href="http://logstash.net/docs/1.4.2/configuration#string">string</a> </li>
<li> There is no default value for this setting. </li>
</ul>
<p>
The plugin will start collecting from the specified time.  If start_time is not provided, the plugin will collect data from current time.

   # times format is  ISO8601 e.g.
<code>start_time => "2015-08-21T14:32:00+0200"</code>
</p>

<h4>
<a name="end_time">
end_time (optional setting)
</a>
</h4>
<ul>
<li> Value type is <a href="http://logstash.net/docs/1.4.2/configuration#string">string</a> </li>
<li> There is no default value for this setting. </li>
</ul>
<p>
The plugin will stop collecting from the specified time.  If stop_time is not provided, the plugin will continue to collect data, moving forward, limited only by wallclock time ( it won't go past current time) and the configured latency setting

   # times format is  ISO8601 e.g.
<code>start_time => "2015-08-21T14:32:00+0200"</code>
</p>
<h4>
<a name="latency">
end_time (optional setting)
</a>
</h4>
<ul>
<li> Value type is <a href="http://logstash.net/docs/1.4.2/configuration#number">number</a> in minutes </li>
<li> Default 0 mins meaning, run up to current wallclock time</li>
</ul>
<p>
As the plugin moves forward through time, extracting data, it will stay behind current time by the specified amount of latency. This is typically used when the data is slow to become available in AppDynamics, e.g. due to slow agent loads or other environmental conditions.
</p>

<h4>
<a name="aggregation_interval">
aggregation_interval (optional setting)
</a>
</h4>
<ul>
<li> Value type is <a href="http://logstash.net/docs/1.4.2/configuration#number">number</a> in minutes </li>
<li> Default 15mins </li>
</ul>
<p>
As the plugin moves through time, it moves forward with this interval. E.g. if it started from 12:00, with this 15min setting, it would poll data for 12:00, then 12:15, then 12:30 and so on. This is usually aligned with the Predictive Insights aggregation interval
</p>
<h4>
<a name="SCAWindowMarker">
end_time (optional setting)
</a>
</h4>

</div>
<!--closes main container div-->
<div class="clear">
</div>
<div class="footer">
<p>
Hello! I'm your friendly footer. If you're actually reading this, I'm impressed.
</p>
</div>
<noscript>
<div style="display:inline;">
<img height="1" width="1" style="border-style:none;" alt="" src="//googleads.g.doubleclick.net/pagead/viewthroughconversion/985891458/?value=0&amp;guid=ON&amp;script=0"/>
</div>
</noscript>
<script src="/js/patch.js?1.4.2"></script>
</body>
</html>
