
#ARIMA based anomaly detection mechanism
This project employes ARIMA in order to perform anomaly detection on timeseries data. From a strict mathematical perspective, ARIMA is used to generate a prediction for a some future time t which is then compared with the observed value. If the value lays outside a predetermined tolerance interval then it is denoted as outlier.    

##Getting started

###Prerequisites

The program is written in python. It should work with both Python 2.7.5 and 3.6.3 however it has been thorougly tested with 2.7.5. Additionally, it needs the following libraries:

* impyla (0.14.1)
* numpy (1.14.3)
* pandas (0.20.3)
* statsmodels (0.9.0)
* configparser (3.5.0)

The program assumes the existence of two tables in the same impala database (database name is configurable); one is used for input and the other for output. Both schemata appear in the following. They both must exist prior to starting this program.

* Input table: system_metrics

```
	CREATE TABLE system_metrics(  
		server STRING,
		device STRING,
		metric STRING,
		time STRING,
		value FLOAT
	)
	partitioned by (pardt STRING)
	ROW FORMAT DELIMITED FIELDS TERMINATED BY ',' STORED AS TEXTFILE
```

* Output table: arima_results (configurable)

```
	CREATE TABLE arima_results(  
		predicted_value FLOAT,
		actual_value FLOAT,
		upper FLOAT,
		lower FLOAT,
		server STRING,
		metric STRING,
		device STRING,
		window_id INT,
		aggregation_level INT,
		current_time STRING
	)
	ROW FORMAT DELIMITED FIELDS TERMINATED BY ',' STORED AS TEXTFILE
```

A number of parameters are required for connecting to impala and properly initiating ARIMA. These parameters are grouped into sections. The program expects at least 3 sections, DEFAULT, IMPALA and a metric. The number and names of the metrics' sections are dynamically configurable. Consider the following example:

* [DEFAULT]: This is the default section. It must appear in the configuration file.
* INIT_TIME_STAMP: The initial timestamp. Corresponds to the time from which we start computations. It should be in format YYYY-DD-MM HH:MM:SS. If left blank the current UTC timestamp is assumed. 
* TIMELENGTH: The computation window in minutes. Setting a value of 10 means that we perform the evaluation every 10 minutes.
* HISTORY: The number of days we consider for building the ARIMA model. Setting to 7 means that we take into account a week-long observations
* THREAD_POOL: The number of threads to start
* METRIC: The metrics for which we perform anomaly detection. Should be provided as a python list. For example, the list ["CPU", "MEMORY", "DISKIO"] means that we build an anomaly detection model for metrics CPU, MEMORY and DISKIO. All metrics defined here are expected to appear as separate section in the configuration file
* LOCAL_DIRECTORY: A directory in the local device used for temporary storage. It is automatically cleaned.
* [IMPALA]: This section provides details for connecting to Impala. It must appear in the file
* HOST: The host
* PORT: The port
* AUTH: The authentication mechanism
* DB: The database
* SSL: Whether to use ssl or not (expects True/False)
* CERTIFICATE: Path to certificate
* LDAP: Whether to use LDAP or not (expects True/False)
* USERNAME: The username. If LDAP is true, then the username is assumed to be LDAP username
* PASSWORD: The password. If LDAP is true, then the password is assumed to be LDAP password
* REMOTE_DIRECTORY: The remote directory to put the results. It should be the HDFS directory corresponding to the defined DB
* RESULTS_TABLE_NAME: The results table name
* [CPU]: This section contanins the ARIMA parameters for the CPU timeseries modelling. A similar section must apppear for all metrics appearing in the list of property METRIC
* P: p of ARIMA
* D: d of ARIMA
* Q: q of ARIMA
* ALPHA: a of ARIMA
* TOLERANCE: tolerance of ARIMA

### Running the program
After setting the properties residing in anomaly/properties.txt, execute run.sh. This will update the PYTHONPATH variable and start the program. Executions takes place in the backgound. All stdout and stderr messages are redirected to separate files names using the current timestamp and the ouput stream logged. For example 20180921_135654_stdout.log is the stdout log for a run that started on 13:56:54 on 21/09/2018

The program is currently deployed on 198.19.45.11 in directory /cloudera/opsan_stream1/runtime/anomalies_arima. Its properties appear in anomaly/properties.txt. Executing run.sh from the command line will start the program in the background.

##Algorithm
The algorithm is simple in nature. It constantly searches for new data, performs predictions using ARIMA, stores the results and sleeps for the time remaining until the completion of the indicated time slot duration. Some details are provided in the following sections.

###Cache memory
Due to the fact that it is highly inefficient to query Impala for the whole history we employ a simple cache memory. For every (server, metric, device) tuple we retain a vector which contains week-long measurements aggregated according to the given time duration (e.g. 1008 10-minute averages or 2016 5-minute averages). This vector is initialized at the beginning of the program; in every loop we calculate only the three latest observations and update it. Assuming we use 10-minutes aggregations then in the first loop we will calculate 1008 values while in the second loop 3; the third value will normally correspond to the new time slot t while the other two values to time slots t-1 and t-2. Moreover,  t0 will be shifted to t1 in order to guarantee that we will always have 1008 values stored.

###Generated results
The following fields are generated: 
* window_id: The window id calculated since 1/1/1970. Assuming 10-minute length windows/time slots then this number correspodns to the number of 10-minute slots since 1/1/1970.
* predicted_value: The predicted value for this windows id (i.e. [t..t+x) where x is the window duration in minutes)
* actual_value: The observed value for the previous window (i.e. [t-x..t) where x is the window duration in minutes)
* upper: The highest tolerable bound; observed value of [t..t+x) must be lower than or equal to this
* lower: The lowest tolerable bound; observed value of [t..t+x) must be higher than or equal to this
* server: The server
* metric: The metric
* device: The device 
* aggregation_level: The aggregation level (window duration in minutes) 
* current_time: The UTC timestamp denoting the time of computation. 
 
In order to create a dataset which contains the prediction and the actual value for a given time window you should use the following SQL query:

```
	SELECT 
		predicted_value AS prediction, 
		upper, lower, current_time, window_id,
		NVL(LAG(actual_value, 1) OVER (PARTITION BY server, metric, device ORDER BY window_id ASC), predicted_value) AS observed_value,  
		CASE
			WHEN NVL(LAG(actual_value, 1) OVER (PARTITION BY server, metric, device ORDER BY window_id ASC), predicted_value)>upper THEN "OUTLIER HIGH"
			WHEN NVL(LAG(actual_value, 1) OVER (PARTITION BY server, metric, device ORDER BY window_id ASC), predicted_value)<lower THEN "OUTLIER LOW"
			ELSE "NORMAL"
		END AS is_outlier,
		server, metric, device
	FROM 
		arima_results
```

