# Workable - MovieRama

This is a small web application that acts as a movie recommender allowing users to get movie recommendations.

## Requirements
The application is built with Python 2.7. Specifically, in order to deploy it on your system, you will need the following:

1. Python 2.7.14 with
* Numpy 1.13.3
* Pandas 0.20.3
* NLTK 3.2.4
* Flask 0.12.2
* sqlalchemy 1.2.10
* scipy 0.19.1
2. MySQL Server 8.0

## Populating the MySQL tables
The first step entails the preprocessing of the MovieLens 20M datasets. You have to download the dataset from [here] (http://files.grouplens.org/datasets/movielens/ml-20m.zip) . The dataset is used in order to retrieve user related information.

### Creating the tables
The sql script for creating the MySQL tables is available in the utils/ directory (ddl.sql). There are three tables, namely:
1. users_genres_index which maintains information regarding the movie genres that a particular user prefers
2. users_movies_tags_index which maintains information regarding the tags that a particular user has attributed to movies
3. users_ratings_index which maintains information regarding the ratings that a user has given to movies

### Loading data
The preprocessing script is located in utils/ and is load_data.py. Upon invocation, it parses the MovieLens 20M collection and creates the corresponding CSVs. You should invoke it by providing the path to the MovieLens 20M dataset. 
```
python load_data.py <path to ml-20m>
```
Thereinafter, data can be loaded in MySQL using the commands in load.sql. Note here that the process can be particularly long; on an Intel Core i7-7500U @ 2.7GHz it takes approximately 6 hours in order to insert all data in the tables.

## Running the application
The application can be run by executing the file web_interface/interface.py. Prior to that, you should fix the properties file. In particular the following properties should be set:

*USERNAME:The database user name
*PASSWORD:The database password
*DATABASE:The database name
*HOST:The host where the MySQL server works
*KEY:The MovieLens key
*OK_CODE:The HTTP code for successful operation (normally it should be 200)
*TOP_K:The number of recommendations per query to generate
*BUILD:Whether or not to build the knowledge base used for recommendations (should be set to 0 or 1)
*STORAGE:The directory where the built models are stored
*KNN:The number of nearest neighbors to employ while building the knowledge base
*WEB_PORT: The port of the web application

Always use ":" in order to separate a property-key from a property-value. Then, invoke the following:

```
python web_interface/interface.py ./properties.txt
```

### Building the model
Setting a value of 1 in the BUILD property triggers the execution of the knowledge base building process. In particular, for every user we extract the genres and attributed tags per viewed movie and create a vector in accordance with the TF-IDF concept. Specifically for the case of genres:
*A = number of times a user watched a movie of genre x
*B = number of times a user watched any movie
*C = number of users
*D = number of times a genre type movie is watched

Thereinafter, we populate the User x Genre matrix as follows: **X[i,j]=(A/B)*log_10(C/D)** where i is the id of the i-th user and j the id of the j-th genre. In a similar fashion we populate the User x Tags matrix Y. It should be noted that tags are preprocessed by means of tokenization and stemming.

Matrixes X,Y are then projected to a lower dimensional space via Random Projections (the number of dimensions is infered by the algorithm using the Johnson–Lindenstrauss lemma -default behavior of SparseRandomProjection class offered by scipy) and subsequently indexed for k-NN search. The results are serialized and stored with pickle. When the BUILD property is set to 0, the knowledge base is populated with pickle and stored in memory. Make sure that in both cases the STORAGE property is set to the same value. The name of the storage file is assigned by the application itself and should not be changed. Calculations may take up to 6 hours depending on the processing power of the host machine. Therefore, a pre-built version of the knowledge base is provided in recommendation_data.zip. You should unzip it in the STORAGE directory.

### API Methods
After the knowledge base's initialization, the application expects requests on port WEB_PORT. There are three methods that can be invoked:
1. get_movies_for_user
*userId: The user id (integer) which is has to be present in the database

The application returns a list of movies (objects of lass Movie from data_models/movie.py) containing the movie's title, description and release year as downloaded from https://www.themoviedb.org/. 

**Examples**

```
curl -i -X GET -H "Content-Type:application/json" http://localhost:8081/get_movies_for_user -d "{\"userId\":\"131784\"}"
```

Indicative result: [
"{\"description\": \"Princess Leia is captured and held hostage by the evil Imperial forces in their effort to take over the galactic Empire. Venturesome Luke Skywalker and dashing captain Han Solo team together with the loveable robot duo R2-D2 and C-3PO to rescue the beautiful princess and restore peace and justice in the Empire.\", \"year\": \"1977\", \"id\": 11, \"title\": \"Star Wars\"}",
"{\"description\": \"Humanity finds a mysterious object buried beneath the lunar surface and sets off to find its origins with the help of HAL 9000, the world's most advanced super computer.\", \"year\": \"1968\", \"id\": 62, \"title\": \"2001: A Space Odyssey\"}",
"{\"description\": \"While serving time for insanity at a state mental hospital, implacable rabble-rouser, Randle Patrick McMurphy inspires his fellow patients to rebel against the authoritarian rule of head nurse, Mildred Ratched.\", \"year\": \"1975\", \"id\": 510, \"title\": \"One Flew Over the Cuckoo's Nest\"}",
"{\"description\": \"The epic saga continues as Luke Skywalker, in hopes of defeating the evil Galactic Empire, learns the ways of the Jedi from aging master Yoda. But Darth Vader is more determined than ever to capture Luke. Meanwhile, rebel leader Princess Leia, cocky Han Solo, Chewbacca, and droids C-3PO and R2-D2 are thrown into various stages of capture, betrayal and despair.\", \"year\": \"1980\", \"id\": 1891, \"title\": \"The Empire Strikes Back\"}",
"{\"description\": \"When Dr. Indiana Jones \\u2013 the tweed-suited professor who just happens to be a celebrated archaeologist \\u2013 is hired by the government to locate the legendary Ark of the Covenant, he finds himself up against the entire Nazi regime.\", \"year\": \"1981\", \"id\": 85, \"title\": \"Raiders of the Lost Ark\"}",
"{\"description\": \"During its return to the earth, commercial spaceship Nostromo intercepts a distress signal from a distant planet. When a three-member team of the crew discovers a chamber containing thousands of eggs on the planet, a creature inside one of the eggs attacks an explorer. The entire crew is unaware of the impending nightmare set to descend upon them when the alien parasite planted inside its unfortunate host is birthed.\", \"year\": \"1979\", \"id\": 348, \"title\": \"Alien\"}"]
```

```
curl -i -X GET -H "Content-Type:application/json" http://localhost:8081/get_movies_for_user -d "{\"userId\":\"-7\"}"
```

```
{
	"Message": "No valid movie list retrieved.",
	"ReturnCode": -1
}
```

```
curl -i -X GET -H "Content-Type:application/json" http://localhost:8081/get_movies_for_user -d "{\"userId\":\"\"}"
```

```
{
	"Message": "Invalid user id.",
	"ReturnCode": -2
}
```

2. set_movies_for_user
*userId: The user id (integer) 
*movieId: The movie id (integer) which has to be present in the database
*rating: The rating of the movie 
*tags: A list of tags 

The application returns 0 upon proper execution (i.e. no error while inserting the data) or an error code from utilities/return_codes.py

**Examples**

```
curl -i -X GET -H "Content-Type:application/json" http://localhost:8081/set_movies_for_user -d "{\"userId\":\"-1\",\"movieId\":\"453\",\"tags\":[\"funnny\",\"hilarious\"], \"rating\":\"5\"}"
```
```
{
  "ReturnCode": 0
}
```

3. get_recommendations_for_user
*userId: The user id (integer). Can be None if both tags and genres are provided 
*tags: A list of tags. It is not considered when the userId is provided since the corresponding information is retrieved from the database.
*genres: A list of genres. It is not considered when the userId is provided since the corresponding information is retrieved from the database.

The application returns a list of movies (objects of class Movie from data_models/movie.py) containing the movie's title, description and release year as downloaded from https://www.themoviedb.org/. 

**Examples**

```
curl -i -X GET -H "Content-Type:application/json" http://localhost:8081/get_movie_recommendations_for_user -d "{\"userId\":\"131784\"}"
```

```
["{\"description\": \"Nine years ago two strangers met by chance and spent a night in Vienna that ended before sunrise. They are about to meet for the first time since. Now they have one afternoon to find out if they belong together.\", \"year\": \"2004\", \"id\": 80, \"title\": \"Before Sunset\"}",
"{\"description\": \"The setting is Detroit in 1995. The city is divided by 8 Mile, a road that splits the town in half along racial lines. A young white rapper, Jimmy \\\"B-Rabbit\\\" Smith Jr. summons strength within himself to cross over these arbitrary boundaries to fulfill his dream of success in hip hop. With his pal Future and the three one third in place, all he has to do is not choke.\", \"year\": \"2002\", \"id\": 65, \"title\": \"8 Mile\"}",
"{\"description\": \"A burger-loving hit man, his philosophical partner, a drug-addled gangster's moll and a washed-up boxer converge in this sprawling, comedic crime caper. Their adventures unfurl in three stories that ingeniously trip back and forth in time.\", \"year\": \"1994\", \"id\": 680, \"title\": \"Pulp Fiction\"}",
"{\"description\": \"King Arthur, accompanied by his squire, recruits his Knights of the Round Table, including Sir Bedevere the Wise, Sir Lancelot the Brave, Sir Robin the Not-Quite-So-Brave-As-Sir-Lancelot and Sir Galahad the Pure. On the way, Arthur battles the Black Knight who, despite having had all his limbs chopped off, insists he can still fight. They reach Camelot, but Arthur decides not  to enter, as \\\"it is a silly place\\\".\", \"year\": \"1975\", \"id\": 762, \"title\": \"Monty Python and the Holy Grail\"}",
"{\"description\": \"A ticking-time-bomb insomniac and a slippery soap salesman channel primal male aggression into a shocking new form of therapy. Their concept catches on, with underground \\\"fight clubs\\\" forming in every town, until an eccentric gets in the way and ignites an out-of-control spiral toward oblivion.\", \"year\": \"1999\", \"id\": 550, \"title\": \"Fight Club\"}",
"{\"description\": \"An assassin is shot at the altar by her ruthless employer, Bill and other members of their assassination circle \\u2013 but 'The Bride' lives to plot her vengeance. Setting out for some payback, she makes a death list and hunts down those who wronged her, saving Bill for last.\", \"year\": \"2003\", \"id\": 24, \"title\": \"Kill Bill: Vol. 1\"}",
"{\"description\": \"After being held captive in an Afghan cave, billionaire engineer Tony Stark creates a unique weaponized suit of armor to fight evil.\", \"year\": \"2008\", \"id\": 1726, \"title\": \"Iron Man\"}",
"{\"description\": \"Dave Lizewski is an unnoticed high school student and comic book fan who one day decides to become a super-hero, even though he has no powers, training or meaningful reason to do so.\", \"year\": \"2010\", \"id\": 23483, \"title\": \"Kick-Ass\"}",
"{\"description\": \"Le Chiffre, a banker to the world's terrorists, is scheduled to participate in a high-stakes poker game in Montenegro, where he intends to use his winnings to establish his financial grip on the terrorist market. M sends Bond \\u2013 on his maiden mission as a 00 Agent \\u2013 to attend this game and prevent Le Chiffre from winning. With the help of Vesper Lynd and Felix Leiter, Bond enters the most important poker game in his already dangerous career.\", \"year\": \"2006\", \"id\": 36557, \"title\": \"Casino Royale\"}",
"{\"description\": \"Top London cop, PC Nicholas Angel is good. Too good.  To stop the rest of his team from looking bad, he is reassigned to the quiet town of Sandford, paired with simple country cop, and everything seems quiet until two actors are found decapitated. It is addressed as an accident, but Angel isn't going to accept that, especially when more and more people turn up dead.\", \"year\": \"2007\", \"id\": 4638, \"title\": \"Hot Fuzz\"}"]
```

```
curl -i -X GET -H "Content-Type:application/json" http://localhost:8081/get_movie_recommendations_for_user -d "{\"tags\":[\"blood\",\"terror\",\"scary\"],\"genres\":[\"thriller\"]}"
```

```
["{\"description\": \"Nine years ago two strangers met by chance and spent a night in Vienna that ended before sunrise. They are about to meet for the first time since. Now they have one afternoon to find out if they belong together.\", \"year\": \"2004\", \"id\": 80, \"title\": \"Before Sunset\"}",
"{\"description\": \"The setting is Detroit in 1995. The city is divided by 8 Mile, a road that splits the town in half along racial lines. A young white rapper, Jimmy \\\"B-Rabbit\\\" Smith Jr. summons strength within himself to cross over these arbitrary boundaries to fulfill his dream of success in hip hop. With his pal Future and the three one third in place, all he has to do is not choke.\", \"year\": \"2002\", \"id\": 65, \"title\": \"8 Mile\"}",
"{\"description\": \"A burger-loving hit man, his philosophical partner, a drug-addled gangster's moll and a washed-up boxer converge in this sprawling, comedic crime caper. Their adventures unfurl in three stories that ingeniously trip back and forth in time.\", \"year\": \"1994\", \"id\": 680, \"title\": \"Pulp Fiction\"}",
"{\"description\": \"King Arthur, accompanied by his squire, recruits his Knights of the Round Table, including Sir Bedevere the Wise, Sir Lancelot the Brave, Sir Robin the Not-Quite-So-Brave-As-Sir-Lancelot and Sir Galahad the Pure. On the way, Arthur battles the Black Knight who, despite having had all his limbs chopped off, insists he can still fight. They reach Camelot, but Arthur decides not  to enter, as \\\"it is a silly place\\\".\", \"year\": \"1975\", \"id\": 762, \"title\": \"Monty Python and the Holy Grail\"}",
"{\"description\": \"A ticking-time-bomb insomniac and a slippery soap salesman channel primal male aggression into a shocking new form of therapy. Their concept catches on, with underground \\\"fight clubs\\\" forming in every town, until an eccentric gets in the way and ignites an out-of-control spiral toward oblivion.\", \"year\": \"1999\", \"id\": 550, \"title\": \"Fight Club\"}",
"{\"description\": \"An assassin is shot at the altar by her ruthless employer, Bill and other members of their assassination circle \\u2013 but 'The Bride' lives to plot her vengeance. Setting out for some payback, she makes a death list and hunts down those who wronged her, saving Bill for last.\", \"year\": \"2003\", \"id\": 24, \"title\": \"Kill Bill: Vol. 1\"}",
"{\"description\": \"After being held captive in an Afghan cave, billionaire engineer Tony Stark creates a unique weaponized suit of armor to fight evil.\", \"year\": \"2008\", \"id\": 1726, \"title\": \"Iron Man\"}",
"{\"description\": \"Dave Lizewski is an unnoticed high school student and comic book fan who one day decides to become a super-hero, even though he has no powers, training or meaningful reason to do so.\", \"year\": \"2010\", \"id\": 23483, \"title\": \"Kick-Ass\"}",
"{\"description\": \"Le Chiffre, a banker to the world's terrorists, is scheduled to participate in a high-stakes poker game in Montenegro, where he intends to use his winnings to establish his financial grip on the terrorist market. M sends Bond \\u2013 on his maiden mission as a 00 Agent \\u2013 to attend this game and prevent Le Chiffre from winning. With the help of Vesper Lynd and Felix Leiter, Bond enters the most important poker game in his already dangerous career.\", \"year\": \"2006\", \"id\": 36557, \"title\": \"Casino Royale\"}",
"{\"description\": \"Top London cop, PC Nicholas Angel is good. Too good.  To stop the rest of his team from looking bad, he is reassigned to the quiet town of Sandford, paired with simple country cop, and everything seems quiet until two actors are found decapitated. It is addressed as an accident, but Angel isn't going to accept that, especially when more and more people turn up dead.\", \"year\": \"2007\", \"id\": 4638, \"title\": \"Hot Fuzz\"}"]
```

## Implementation Details
The following sections provide a number of details regarding the internal implementation of specific components. In particular the internals of the recommendation algorithm and the cache memory are presented. 

### Recommendation Engine
The recommendations engine essentially issues two k-NN queries in the genres and tags indexes. The results comprise other users which are similar to the query with respect to genres of watched movies (R1) and attributed tags (R2). The final set of similar users is calculated as the interesection of R1 and R2, or R1 if the former does not exist. The final list of movies ids is retrieved by issuing a query in the database and retaining the top-K rated movies. Their details are then downloaded from TMDB.

### Cache
Assuming that you have run the examples above you should have noticed that querying the database and then TMDB takes some time. In order to speed up the process, the application employs a simple cache mechanism that maintains the last 100 results in memory (FIFO priority). The caching mechanism is applied to movie and recommendations retrieval as well as the maintenance of the knowledge base in main memory.

### Benchmarking
In order to assess the quality of the recommendations, a set of 1000 users was used as benchmark dataset. The goal was to compare the generated recommendations against the movies viewed. The evaluation process is the following:

1. Randomly select 1000 users from the database
2. For every user 
*Create the genre and tags boolean vectors (i.e. set 1 if the tag/genre is valid for the user otherwise 0)
*Project to the lower dimensional space
*Issue k-NN query to the knowledge base and retrieve similar users
*Retain top-k movies
*Calculate true positives as the intersection of suggested movies with the movies watched and false positives as the difference between these sets.
3. Report average precision@top k
 
The precision@Top-10 predictions for the 1000 users sample is ~28%. The corresponding test file is in tester.py located in package tester. It can be invoked as follows:

```
python tester/tester.py ./properties.txt
```

In order to speed up the process make sure you uncomment the following line during test in method get_recommended_movies_for_user of recommender.py.
```
return A.iloc[:, 0].values.tolist()
```



